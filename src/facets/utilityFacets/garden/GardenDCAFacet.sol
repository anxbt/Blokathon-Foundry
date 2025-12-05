// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {GardenStorage} from "./GardenStorage.sol";
import {DCAFacetStorage} from "../dca/DCAFacetStorage.sol";
import {Facet} from "../../Facet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Thrown when garden is not active
error GardenDCA_GardenNotActive();

/// @notice Thrown when plan is not active
error GardenDCA_PlanNotActive();

/// @notice Thrown when execution is too early
error GardenDCA_TooEarly();

/// @notice Thrown when plan is already finished
error GardenDCA_PlanFinished();

/// @notice Thrown when swap data array length doesn't match garden assets
error GardenDCA_SwapDataMismatch();

/// @notice Thrown when router is not set
error GardenDCA_RouterNotSet();

/// @notice Thrown when swap fails
error GardenDCA_SwapFailed(uint256 index);

/// @notice Thrown when amount is zero
error GardenDCA_InvalidAmount();

/// @notice Thrown when interval is too small
error GardenDCA_IntervalTooSmall();

/// @notice Thrown when total intervals is zero
error GardenDCA_InvalidTotalIntervals();

/**
 * @title GardenDCAFacet
 * @author BLOK Capital DAO
 * @notice Facet for DCA plans targeting Gardens (multi-asset baskets)
 * @dev Creates DCA plans that split swaps across multiple assets according to weights
 */
contract GardenDCAFacet is Facet {
    // ========================================================================
    // Events
    // ========================================================================

    /// @notice Emitted when a garden DCA plan is created
    event GardenPlanCreated(
        uint256 indexed planId,
        address indexed user,
        uint256 indexed gardenId
    );

    /// @notice Emitted when a garden DCA step is executed
    event GardenStepExecuted(
        uint256 indexed planId,
        uint256 indexed step,
        uint256 amountIn
    );

    // ========================================================================
    // External Functions (State-Changing)
    // ========================================================================

    /**
     * @notice Creates a DCA plan targeting a garden
     * @param tokenIn The token to swap from
     * @param amountPerInterval Amount of tokenIn per interval
     * @param intervalSeconds Time between executions
     * @param totalIntervals Total number of swaps to perform
     * @param gardenId The garden to invest into
     * @return planId The ID of the created plan
     */
    function createGardenPlan(
        address tokenIn,
        uint256 amountPerInterval,
        uint256 intervalSeconds,
        uint256 totalIntervals,
        uint256 gardenId
    ) external nonReentrant returns (uint256 planId) {
        if (amountPerInterval == 0) revert GardenDCA_InvalidAmount();
        if (intervalSeconds < 60) revert GardenDCA_IntervalTooSmall();
        if (totalIntervals == 0) revert GardenDCA_InvalidTotalIntervals();

        // Verify garden exists and is active
        GardenStorage.Layout storage gs = GardenStorage.layout();
        GardenStorage.Garden storage garden = gs.gardens[gardenId];
        if (!garden.active) revert GardenDCA_GardenNotActive();

        DCAFacetStorage.Layout storage s = DCAFacetStorage.layout();
        planId = s.nextPlanId++;

        uint256 totalAmount = amountPerInterval * totalIntervals;

        // Transfer tokens from user
        IERC20(tokenIn).transferFrom(msg.sender, address(this), totalAmount);

        // Create plan
        DCAFacetStorage.Plan storage p = s.plans[planId];
        p.user = msg.sender;
        p.tokenIn = tokenIn;
        p.tokenOut = address(0); // No single tokenOut for garden plans
        p.amountPerInterval = amountPerInterval;
        p.intervalSeconds = intervalSeconds;
        p.totalIntervals = totalIntervals;
        p.executedIntervals = 0;
        p.nextExecutionTimestamp = block.timestamp + intervalSeconds;
        p.active = true;

        // Link plan to garden
        s.planGarden[planId] = gardenId;
        s.userPlans[msg.sender].push(planId);

        emit GardenPlanCreated(planId, msg.sender, gardenId);
    }

    /**
     * @notice Executes a garden DCA step, splitting across all garden assets
     * @param planId The plan to execute
     * @param swapData Array of encoded swap calls, one per garden asset
     */
    function executeGardenStep(
        uint256 planId,
        bytes[] calldata swapData
    ) external nonReentrant {
        DCAFacetStorage.Layout storage s = DCAFacetStorage.layout();
        DCAFacetStorage.Plan storage p = s.plans[planId];

        // Validations
        if (!p.active) revert GardenDCA_PlanNotActive();
        if (block.timestamp < p.nextExecutionTimestamp)
            revert GardenDCA_TooEarly();
        if (p.executedIntervals >= p.totalIntervals)
            revert GardenDCA_PlanFinished();

        address router = s.swapRouter;
        if (router == address(0)) revert GardenDCA_RouterNotSet();

        // Get garden
        uint256 gardenId = s.planGarden[planId];
        GardenStorage.Layout storage gs = GardenStorage.layout();
        GardenStorage.Garden storage garden = gs.gardens[gardenId];

        if (!garden.active) revert GardenDCA_GardenNotActive();
        if (swapData.length != garden.assets.length)
            revert GardenDCA_SwapDataMismatch();

        uint256 amountIn = p.amountPerInterval;

        // CHECKS-EFFECTS: Update state BEFORE external calls
        p.executedIntervals += 1;
        if (p.executedIntervals >= p.totalIntervals) {
            p.active = false;
        } else {
            p.nextExecutionTimestamp = block.timestamp + p.intervalSeconds;
        }

        // INTERACTIONS: Execute swaps for each asset
        for (uint256 i = 0; i < garden.assets.length; i++) {
            // Calculate proportional amount: (amountPerInterval * weightBps) / 10000
            uint256 proportionalAmount = (amountIn * garden.weights[i]) / 10000;

            if (proportionalAmount > 0) {
                // Approve router for this portion
                IERC20(p.tokenIn).approve(router, proportionalAmount);

                // Execute swap
                (bool success, ) = router.call(swapData[i]);
                if (!success) revert GardenDCA_SwapFailed(i);
            }
        }

        emit GardenStepExecuted(planId, p.executedIntervals, amountIn);
    }

    // ========================================================================
    // External Functions (View)
    // ========================================================================

    /**
     * @notice Gets the garden ID linked to a plan
     * @param planId The plan ID to query
     * @return gardenId The linked garden ID (0 if not a garden plan)
     */
    function getPlanGarden(
        uint256 planId
    ) external view returns (uint256 gardenId) {
        return DCAFacetStorage.layout().planGarden[planId];
    }

    /**
     * @notice Checks if a plan is a garden plan
     * @param planId The plan ID to check
     * @return isGardenPlan True if this is a garden plan
     */
    function isGardenPlan(uint256 planId) external view returns (bool) {
        DCAFacetStorage.Layout storage s = DCAFacetStorage.layout();
        return
            s.planGarden[planId] != 0 || s.plans[planId].tokenOut == address(0);
    }
}
