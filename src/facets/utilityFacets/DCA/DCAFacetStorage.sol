// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library DCAFacetStorage {
    bytes32 constant STORAGE_POSITION = keccak256("dca.facet.storage");

    struct Plan {
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

    struct Layout {
        // planId => Plan
        mapping(uint256 => Plan) plans;
        // user => list of planIds
        mapping(address => uint256[]) userPlans;
        uint256 nextPlanId;
        // router used for swaps (e.g. UniswapV2-like router)
        address swapRouter;
        // allowed tokens to be used as tokenIn (optional governance)
        mapping(address => bool) allowedTokenIn;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly { l.slot := position }
    }
}