// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {GardenStorage} from "./GardenStorage.sol";
import {Facet} from "../../Facet.sol";

/// @notice Thrown when arrays have mismatched lengths
error Garden_ArrayLengthMismatch();

/// @notice Thrown when weights don't sum to 10000 basis points
error Garden_InvalidWeights();

/// @notice Thrown when garden is not active
error Garden_NotActive();

/// @notice Thrown when garden doesn't exist
error Garden_NotFound();

/// @notice Thrown when trying to create garden with no assets
error Garden_EmptyAssets();

/**
 * @title GardenFacet
 * @author BLOK Capital DAO
 * @notice Facet for managing Gardens (curated multi-asset baskets)
 * @dev Only Diamond owner can create, update, and remove gardens
 */
contract GardenFacet is Facet {
    // ========================================================================
    // Events
    // ========================================================================

    event GardenCreated(
        uint256 indexed gardenId,
        string name,
        address[] assets,
        uint16[] weights
    );
    event GardenUpdated(
        uint256 indexed gardenId,
        address[] assets,
        uint16[] weights
    );
    event GardenRemoved(uint256 indexed gardenId);

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /**
     * @notice Creates a new garden with specified assets and weights
     * @param name Human-readable name for the garden
     * @param assets Array of token addresses in the basket
     * @param weights Array of weights in basis points (must sum to 10000)
     * @return gardenId The ID of the newly created garden
     */
    function createGarden(
        string calldata name,
        address[] calldata assets,
        uint16[] calldata weights
    ) external onlyDiamondOwner returns (uint256 gardenId) {
        if (assets.length == 0) revert Garden_EmptyAssets();
        if (assets.length != weights.length)
            revert Garden_ArrayLengthMismatch();
        if (!_validateWeights(weights)) revert Garden_InvalidWeights();

        GardenStorage.Layout storage s = GardenStorage.layout();
        gardenId = s.nextGardenId++;

        GardenStorage.Garden storage garden = s.gardens[gardenId];
        garden.name = name;
        garden.assets = assets;
        garden.weights = weights;
        garden.active = true;

        emit GardenCreated(gardenId, name, assets, weights);
    }

    /**
     * @notice Updates an existing garden's assets and weights
     * @param gardenId The ID of the garden to update
     * @param assets New array of token addresses
     * @param weights New array of weights in basis points
     */
    function updateGarden(
        uint256 gardenId,
        address[] calldata assets,
        uint16[] calldata weights
    ) external onlyDiamondOwner {
        GardenStorage.Layout storage s = GardenStorage.layout();
        GardenStorage.Garden storage garden = s.gardens[gardenId];

        if (!garden.active) revert Garden_NotActive();
        if (assets.length == 0) revert Garden_EmptyAssets();
        if (assets.length != weights.length)
            revert Garden_ArrayLengthMismatch();
        if (!_validateWeights(weights)) revert Garden_InvalidWeights();

        garden.assets = assets;
        garden.weights = weights;

        emit GardenUpdated(gardenId, assets, weights);
    }

    /**
     * @notice Removes a garden by setting it to inactive
     * @param gardenId The ID of the garden to remove
     */
    function removeGarden(uint256 gardenId) external onlyDiamondOwner {
        GardenStorage.Layout storage s = GardenStorage.layout();
        GardenStorage.Garden storage garden = s.gardens[gardenId];

        if (bytes(garden.name).length == 0) revert Garden_NotFound();

        garden.active = false;

        emit GardenRemoved(gardenId);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /**
     * @notice Gets garden details by ID
     * @param gardenId The ID of the garden to retrieve
     * @return name The garden name
     * @return assets The array of asset addresses
     * @return weights The array of weights in basis points
     * @return active Whether the garden is active
     */
    function getGarden(
        uint256 gardenId
    )
        external
        view
        returns (
            string memory name,
            address[] memory assets,
            uint16[] memory weights,
            bool active
        )
    {
        GardenStorage.Layout storage s = GardenStorage.layout();
        GardenStorage.Garden storage garden = s.gardens[gardenId];

        return (garden.name, garden.assets, garden.weights, garden.active);
    }

    /**
     * @notice Gets the next garden ID that will be assigned
     * @return The next garden ID
     */
    function getNextGardenId() external view returns (uint256) {
        return GardenStorage.layout().nextGardenId;
    }

    // ========================================================================
    // Internal Functions
    // ========================================================================

    /**
     * @notice Validates that weights sum to exactly 10000 basis points
     * @param weights Array of weights to validate
     * @return valid True if weights sum to 10000
     */
    function _validateWeights(
        uint16[] calldata weights
    ) internal pure returns (bool valid) {
        uint256 total;
        for (uint256 i = 0; i < weights.length; i++) {
            total += weights[i];
        }
        return total == 10000;
    }
}
