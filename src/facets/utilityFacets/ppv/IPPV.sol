// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPPV
 * @notice Interface for Principal Protected Vault Facet
 */

interface IPPV {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a user deposits into the vault
    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 feeDeducted,
        uint256 amountInvested
    );

    /// @notice Emitted when a user withdraws from the vault
    event Withdrawn(
        address indexed user,
        uint256 principal,
        uint256 portfolioValue,
        uint256 reserveUsed,
        uint256 totalPaid
    );

    /// @notice Emitted when the reserve is funded
    event ReserveFunded(address indexed funder, uint256 amount);

    /// @notice Emitted when reserve is used to cover a loss
    event ReserveUsed(address indexed user, uint256 amount);

    /// @notice Emitted when vault is paused/unpaused
    event VaultPaused(bool paused);

    // ========================================================================
    // User Functions
    // ========================================================================

    /// @notice Deposit tokens into the vault
    /// @param amount Amount of deposit token to deposit
    function deposit(uint256 amount) external;

    /// @notice Withdraw all funds from the vault (principal protected)
    function withdraw() external;

    // ========================================================================
    // View Functions
    // ========================================================================

    /// @notice Get user's original deposit (principal)
    /// @param user Address to query
    /// @return principal The original deposit amount
    function getUserPrincipal(
        address user
    ) external view returns (uint256 principal);

    /// @notice Get user's current portfolio value in Aave
    /// @param user Address to query
    /// @return value Current value of user's share in Aave
    function getUserPortfolioValue(
        address user
    ) external view returns (uint256 value);

    /// @notice Get total deposits across all users
    /// @return total Sum of all user principals
    function getTotalDeposits() external view returns (uint256 total);

    /// @notice Get current reserve balance
    /// @return balance Reserve balance available for protection
    function getReserveBalance() external view returns (uint256 balance);

    /// @notice Get current insurance fee in basis points
    /// @return feeBps Fee in basis points (100 = 1%)
    function getInsuranceFeeBps() external view returns (uint16 feeBps);

    /// @notice Get the deposit token address
    /// @return token Address of the deposit token
    function getDepositToken() external view returns (address token);

    /// @notice Check if vault is paused
    /// @return isPaused True if vault is paused
    function isPaused() external view returns (bool isPaused);

    // ========================================================================
    // Admin Functions
    // ========================================================================

    /// @notice Set the deposit token (only callable once or when no deposits)
    /// @param token Address of the ERC20 token to accept
    function setDepositToken(address token) external;

    /// @notice Set the insurance fee
    /// @param feeBps Fee in basis points (max 1000 = 10%)
    function setInsuranceFeeBps(uint16 feeBps) external;

    /// @notice Fund the insurance reserve
    /// @param amount Amount to add to reserve
    function fundReserve(uint256 amount) external;

    /// @notice Withdraw from the reserve (emergency only)
    /// @param amount Amount to withdraw from reserve
    function withdrawReserve(uint256 amount) external;

    /// @notice Pause/unpause the vault
    /// @param _paused True to pause, false to unpause
    function setPaused(bool _paused) external;
}
