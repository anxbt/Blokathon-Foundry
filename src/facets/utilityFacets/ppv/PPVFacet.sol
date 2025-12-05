// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PPVFacet (Principal Protected Vault)
 * @notice Vault that guarantees users get back at least their principal
 * @dev Integrates with Aave V3 for yield, uses insurance reserve to cover losses
 */

// OpenZeppelin Contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Aave Contracts
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {
    DataTypes
} from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

// Local Contracts
import {Facet} from "src/facets/Facet.sol";
import {IPPV} from "src/facets/utilityFacets/ppv/IPPV.sol";
import {PPVStorage} from "src/facets/utilityFacets/ppv/PPVStorage.sol";

// ============================================================================
// Errors
// ============================================================================

/// @notice Thrown when deposit amount is zero
error PPV_InvalidAmount();

/// @notice Thrown when deposit token is not set
error PPV_DepositTokenNotSet();

/// @notice Thrown when user has no deposit
error PPV_NoDeposit();

/// @notice Thrown when user already has a deposit
error PPV_AlreadyHasDeposit();

/// @notice Thrown when vault is paused
error PPV_VaultPaused();

/// @notice Thrown when fee is too high
error PPV_FeeTooHigh();

/// @notice Thrown when reserve is insufficient for withdrawal
error PPV_InsufficientReserve();

/// @notice Thrown when trying to change token with active deposits
error PPV_CannotChangeTokenWithDeposits();

/// @notice Thrown when token address is zero
error PPV_InvalidTokenAddress();

// ============================================================================
// Constants
// ============================================================================

/// @dev Maximum insurance fee (10%)
uint16 constant MAX_FEE_BPS = 1000;

/// @dev Basis points denominator
uint16 constant BPS_DENOMINATOR = 10000;

/// @dev Aave V3 Pool on Base (same as AaveV3Base)
address constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

// ============================================================================
// PPVFacet Contract
// ============================================================================

contract PPVFacet is IPPV, Facet {
    using SafeERC20 for IERC20;

    // ========================================================================
    // User Functions
    // ========================================================================

    /// @inheritdoc IPPV
    function deposit(uint256 amount) external nonReentrant {
        PPVStorage.Layout storage s = PPVStorage.layout();

        // Checks
        if (s.paused) revert PPV_VaultPaused();
        if (amount == 0) revert PPV_InvalidAmount();
        if (s.depositToken == address(0)) revert PPV_DepositTokenNotSet();
        if (s.userDeposits[msg.sender].hasDeposit)
            revert PPV_AlreadyHasDeposit();

        // Calculate fee and amount to invest
        uint256 fee = (amount * s.insuranceFeeBps) / BPS_DENOMINATOR;
        uint256 amountToInvest = amount - fee;

        // Transfer tokens from user
        IERC20(s.depositToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Add fee to reserve
        s.reserveBalance += fee;

        // Record user deposit
        s.userDeposits[msg.sender] = PPVStorage.UserDeposit({
            principal: amount,
            depositTimestamp: block.timestamp,
            hasDeposit: true
        });

        // Update totals
        s.totalDeposits += amount;
        s.totalInvested += amountToInvest;

        // Invest in Aave
        _investInAave(s.depositToken, amountToInvest);

        emit Deposited(msg.sender, amount, fee, amountToInvest);
    }

    /// @inheritdoc IPPV
    function withdraw() external nonReentrant {
        PPVStorage.Layout storage s = PPVStorage.layout();

        // Checks
        if (s.paused) revert PPV_VaultPaused();
        if (!s.userDeposits[msg.sender].hasDeposit) revert PPV_NoDeposit();

        PPVStorage.UserDeposit memory userDeposit = s.userDeposits[msg.sender];
        uint256 principal = userDeposit.principal;

        // Calculate user's share of the Aave position
        uint256 portfolioValue = _getUserPortfolioValue(msg.sender);

        // Withdraw from Aave
        uint256 withdrawnAmount = _withdrawFromAave(
            s.depositToken,
            portfolioValue
        );

        uint256 reserveUsed = 0;
        uint256 totalPaid;

        if (withdrawnAmount >= principal) {
            // User made profit or broke even
            totalPaid = withdrawnAmount;
        } else {
            // User has a loss - use reserve to cover
            uint256 shortfall = principal - withdrawnAmount;

            if (s.reserveBalance >= shortfall) {
                // Reserve can cover the loss
                reserveUsed = shortfall;
                s.reserveBalance -= shortfall;
                totalPaid = principal; // User gets full principal back
            } else {
                // Reserve can't fully cover - give what we can
                // (Pro-rata protection)
                reserveUsed = s.reserveBalance;
                s.reserveBalance = 0;
                totalPaid = withdrawnAmount + reserveUsed;
            }

            if (reserveUsed > 0) {
                emit ReserveUsed(msg.sender, reserveUsed);
            }
        }

        // Clear user deposit
        delete s.userDeposits[msg.sender];

        // Update totals
        s.totalDeposits -= principal;
        s.totalInvested -= (principal -
            ((principal * s.insuranceFeeBps) / BPS_DENOMINATOR));

        // Transfer to user
        IERC20(s.depositToken).safeTransfer(msg.sender, totalPaid);

        emit Withdrawn(
            msg.sender,
            principal,
            portfolioValue,
            reserveUsed,
            totalPaid
        );
    }

    // ========================================================================
    // View Functions
    // ========================================================================

    /// @inheritdoc IPPV
    function getUserPrincipal(address user) external view returns (uint256) {
        return PPVStorage.layout().userDeposits[user].principal;
    }

    /// @inheritdoc IPPV
    function getUserPortfolioValue(
        address user
    ) external view returns (uint256) {
        return _getUserPortfolioValue(user);
    }

    /// @inheritdoc IPPV
    function getTotalDeposits() external view returns (uint256) {
        return PPVStorage.layout().totalDeposits;
    }

    /// @inheritdoc IPPV
    function getReserveBalance() external view returns (uint256) {
        return PPVStorage.layout().reserveBalance;
    }

    /// @inheritdoc IPPV
    function getInsuranceFeeBps() external view returns (uint16) {
        return PPVStorage.layout().insuranceFeeBps;
    }

    /// @inheritdoc IPPV
    function getDepositToken() external view returns (address) {
        return PPVStorage.layout().depositToken;
    }

    /// @inheritdoc IPPV
    function isPaused() external view returns (bool) {
        return PPVStorage.layout().paused;
    }

    // ========================================================================
    // Admin Functions
    // ========================================================================

    /// @inheritdoc IPPV
    function setDepositToken(address token) external onlyDiamondOwner {
        PPVStorage.Layout storage s = PPVStorage.layout();

        if (token == address(0)) revert PPV_InvalidTokenAddress();
        if (s.totalDeposits > 0) revert PPV_CannotChangeTokenWithDeposits();

        s.depositToken = token;
    }

    /// @inheritdoc IPPV
    function setInsuranceFeeBps(uint16 feeBps) external onlyDiamondOwner {
        if (feeBps > MAX_FEE_BPS) revert PPV_FeeTooHigh();
        PPVStorage.layout().insuranceFeeBps = feeBps;
    }

    /// @inheritdoc IPPV
    function fundReserve(uint256 amount) external nonReentrant {
        PPVStorage.Layout storage s = PPVStorage.layout();

        if (amount == 0) revert PPV_InvalidAmount();
        if (s.depositToken == address(0)) revert PPV_DepositTokenNotSet();

        IERC20(s.depositToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        s.reserveBalance += amount;

        emit ReserveFunded(msg.sender, amount);
    }

    /// @inheritdoc IPPV
    function withdrawReserve(
        uint256 amount
    ) external onlyDiamondOwner nonReentrant {
        PPVStorage.Layout storage s = PPVStorage.layout();

        if (amount > s.reserveBalance) revert PPV_InsufficientReserve();

        s.reserveBalance -= amount;
        IERC20(s.depositToken).safeTransfer(msg.sender, amount);
    }

    /// @inheritdoc IPPV
    function setPaused(bool _paused) external onlyDiamondOwner {
        PPVStorage.layout().paused = _paused;
        emit VaultPaused(_paused);
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /// @notice Calculate user's current portfolio value based on their share
    function _getUserPortfolioValue(
        address user
    ) internal view returns (uint256) {
        PPVStorage.Layout storage s = PPVStorage.layout();

        if (!s.userDeposits[user].hasDeposit) return 0;
        if (s.totalInvested == 0) return 0;

        // Get total Aave position (aToken balance)
        uint256 totalAavePosition = _getAaveBalance(s.depositToken);

        // Calculate user's share based on their invested amount
        uint256 userInvested = s.userDeposits[user].principal -
            ((s.userDeposits[user].principal * s.insuranceFeeBps) /
                BPS_DENOMINATOR);

        // User's portfolio value = (userInvested / totalInvested) * totalAavePosition
        return (userInvested * totalAavePosition) / s.totalInvested;
    }

    /// @notice Get current aToken balance for the deposit token
    function _getAaveBalance(address token) internal view returns (uint256) {
        DataTypes.ReserveData memory reserve = IPool(AAVE_V3_POOL)
            .getReserveData(token);
        if (reserve.aTokenAddress == address(0)) return 0;
        return IERC20(reserve.aTokenAddress).balanceOf(address(this));
    }

    /// @notice Invest tokens into Aave
    function _investInAave(address token, uint256 amount) internal {
        IERC20(token).forceApprove(AAVE_V3_POOL, amount);
        IPool(AAVE_V3_POOL).supply(token, amount, address(this), 0);
    }

    /// @notice Withdraw tokens from Aave
    function _withdrawFromAave(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        if (amount == 0) return 0;

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IPool(AAVE_V3_POOL).withdraw(token, amount, address(this));
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        return balanceAfter - balanceBefore;
    }
}
