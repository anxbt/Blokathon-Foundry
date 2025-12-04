// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDCAFacet {
    event PlanCreated(uint256 indexed planId, address indexed user);
    event PlanCancelled(uint256 indexed planId);
    event StepExecuted(
        uint256 indexed planId,
        uint256 indexed step,
        uint256 amountIn
    );
    event RouterSet(address indexed router);

    struct ViewPlan {
        uint256 planId;
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountPerInterval;
        uint256 intervalSeconds;
        uint256 totalIntervals;
        uint256 executedIntervals;
        uint256 nextExecutionTimestamp;
        bool active;
    }

    function createPlan(
        address tokenIn,
        address tokenOut,
        uint256 amountPerInterval,
        uint256 intervalSeconds,
        uint256 totalIntervals
    ) external returns (uint256);
    function cancelPlan(uint256 planId) external;
    function executeStep(uint256 planId, bytes calldata swapData) external;
    function setRouter(address router) external;
    function getRouter() external view returns (address);
    function getPlan(uint256 planId) external view returns (ViewPlan memory);
    function getUserPlans(
        address user
    ) external view returns (uint256[] memory);
}
