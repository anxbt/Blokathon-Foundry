// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PPVStorage
 * @notice Diamond storage for Principal Protected Vault
 */

library PPVStorage {
    /// @notice Fixed storage slot for PPV persistent state
    bytes32 internal constant PPV_STORAGE_POSITION =
        keccak256("blok.ppv.storage");

    /// @notice User deposit information
    struct UserDeposit {
        uint256 principal; // Original amount deposited (before fees)
        uint256 depositTimestamp; // When the deposit was made
        bool hasDeposit; // Whether user has an active deposit
    }

    /// @notice Layout for the PPV Storage
    struct Layout {
        // Token configuration
        address depositToken; // The token users deposit (e.g., USDC)
        // Fee configuration (in basis points, 100 = 1%)
        uint16 insuranceFeeBps; // Fee taken on deposit and sent to reserve
        // Reserve tracking
        uint256 reserveBalance; // Insurance reserve balance
        // Total tracking
        uint256 totalDeposits; // Sum of all user principals
        uint256 totalInvested; // Amount currently in Aave (after fees)
        // User deposits
        mapping(address => UserDeposit) userDeposits;
        // Paused state
        bool paused;
    }

    /// @notice Returns a pointer to the PPV storage layout
    /// @return l Storage pointer to the PPV Storage struct
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = PPV_STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
