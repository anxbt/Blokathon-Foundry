// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./DCAFacetStorage.sol";
import "./IDCAFacet.sol";
import "./DCAFacetBase.sol";
import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2RouterLike {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract DCAFacet is IDCAFacet, DCAFacetBase {
    using DCAFacetStorage for DCAFacetStorage.Layout;

    modifier onlyActive(uint256 planId) {
        DCAFacetStorage.Layout storage s = DCAFacetStorage.layout();
        require(s.plans[planId].active, "DCA: inactive");
        _;
    }

    function setRouter(address router) external override onlyDiamondOwner {
        require(router != address(0), "DCA: zero router");
        DCAFacetStorage.layout().swapRouter = router;
        emit RouterSet(router);
    }

    /// @notice Gets the current swap router address
    /// @return The address of the configured swap router
    function getRouter() external view returns (address) {
        return DCAFacetStorage.layout().swapRouter;
    }

    function createPlan(
        address tokenIn,
        address tokenOut,
        uint256 amountPerInterval,
        uint256 intervalSeconds,
        uint256 totalIntervals
    ) external override returns (uint256) {
        require(amountPerInterval > 0, "DCA: amount 0");
        require(intervalSeconds >= 60, "DCA: interval too small");
        require(totalIntervals > 0, "DCA: total 0");
        DCAFacetStorage.Layout storage s = DCAFacetStorage.layout();

        uint256 planId = s.nextPlanId++;
        uint256 totalAmount = amountPerInterval * totalIntervals;

        // transfer tokens in
        IERC20(tokenIn).transferFrom(msg.sender, address(this), totalAmount);

        DCAFacetStorage.Plan storage p = s.plans[planId];
        p.user = msg.sender;
        p.tokenIn = tokenIn;
        p.tokenOut = tokenOut;
        p.amountPerInterval = amountPerInterval;
        p.intervalSeconds = intervalSeconds;
        p.totalIntervals = totalIntervals;
        p.executedIntervals = 0;
        p.nextExecutionTimestamp = block.timestamp + intervalSeconds;
        p.active = true;

        s.userPlans[msg.sender].push(planId);

        emit PlanCreated(planId, msg.sender);
        return planId;
    }

    //Why transfer upfront?
    //Because future DCA steps must have guaranteed liquidity.

    function cancelPlan(uint256 planId) external override {
        DCAFacetStorage.Plan storage p = DCAFacetStorage.layout().plans[planId];
        require(p.user == msg.sender, "DCA: not owner");
        require(p.active, "DCA: no active plan");

        // return remaining tokenIn to user
        uint256 remaining = (p.totalIntervals - p.executedIntervals) *
            p.amountPerInterval;
        p.active = false;
        if (remaining > 0) {
            IERC20(p.tokenIn).transfer(msg.sender, remaining);
        }
        emit PlanCancelled(planId);
    }

    function executeStep(
        uint256 planId,
        bytes calldata swapData
    ) external override onlyActive(planId) {
        DCAFacetStorage.Layout storage s = DCAFacetStorage.layout();
        DCAFacetStorage.Plan storage p = s.plans[planId];
        require(block.timestamp >= p.nextExecutionTimestamp, "DCA: too early");
        require(p.executedIntervals < p.totalIntervals, "DCA: finished");

        uint256 amountIn = p.amountPerInterval;

        // approve router if needed
        address router = s.swapRouter;
        require(router != address(0), "DCA: router unset");

        IERC20(p.tokenIn).approve(router, amountIn);

        // For maximum flexibility we allow callers to pass arbitrary calldata and target router
        // But to keep it simple: expect `swapData` to encode method selector + params for UniswapV2-like swap
        // We'll perform low-level call

        (bool ok, ) = router.call(swapData);
        require(ok, "DCA: swap failed");

        p.executedIntervals += 1;
        if (p.executedIntervals < p.totalIntervals) {
            p.nextExecutionTimestamp = block.timestamp + p.intervalSeconds;
        } else {
            p.active = false;
        }

        emit StepExecuted(planId, p.executedIntervals, amountIn);
    }

    function getPlan(
        uint256 planId
    ) external view override returns (ViewPlan memory) {
        DCAFacetStorage.Plan storage p = DCAFacetStorage.layout().plans[planId];
        return
            ViewPlan({
                planId: planId,
                user: p.user,
                tokenIn: p.tokenIn,
                tokenOut: p.tokenOut,
                amountPerInterval: p.amountPerInterval,
                intervalSeconds: p.intervalSeconds,
                totalIntervals: p.totalIntervals,
                executedIntervals: p.executedIntervals,
                nextExecutionTimestamp: p.nextExecutionTimestamp,
                active: p.active
            });
    }

    function getUserPlans(
        address user
    ) external view override returns (uint256[] memory) {
        return DCAFacetStorage.layout().userPlans[user];
    }
}
