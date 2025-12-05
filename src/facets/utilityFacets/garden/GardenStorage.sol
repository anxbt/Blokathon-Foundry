// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title GardenStorage
 * @author BLOK Capital DAO
 * @notice Storage library for Garden (multi-asset basket) data
 * @dev Uses Diamond storage pattern with namespaced slots
 */
library GardenStorage {
    bytes32 constant STORAGE_POSITION = keccak256("garden.storage");

    /// @notice Represents a curated multi-asset basket
    struct Garden {
        string name;
        address[] assets;
        uint16[] weights; // basis points, must sum to 10000
        bool active;
    }

    struct Layout {
        // gardenId => Garden
        mapping(uint256 => Garden) gardens;
        uint256 nextGardenId;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
