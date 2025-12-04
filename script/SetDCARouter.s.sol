// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseScript} from "./Base.s.sol";
import {console} from "forge-std/console.sol";
import {IDCAFacet} from "src/facets/utilityFacets/dca/IDCAFacet.sol";

/**
 * @title SetDCARouter
 * @notice Script to set the Uniswap V2 router address in the DCA facet
 * @dev Run this after deploying the Diamond and DCA facet
 *
 * Usage:
 * forge script script/SetDCARouter.s.sol \
 *   --rpc-url $RPC_URL_BASE \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast
 */
contract SetDCARouterScript is BaseScript {
    // BASE chain Uniswap V2-style router
    address constant BASE_UNISWAP_V2_ROUTER =
        0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

    // IMPORTANT: Set your deployed Diamond address here
    address constant DIAMOND_ADDRESS = address(0); // <-- UPDATE THIS!

    function run() public broadcaster {
        setUp();

        require(
            DIAMOND_ADDRESS != address(0),
            "Please set DIAMOND_ADDRESS in the script"
        );

        console.log("Setting DCA Router on Diamond:", DIAMOND_ADDRESS);
        console.log("Router address:", BASE_UNISWAP_V2_ROUTER);
        console.log("Caller (should be Diamond owner):", deployer);

        // Call setRouter through the Diamond proxy
        IDCAFacet dcaFacet = IDCAFacet(DIAMOND_ADDRESS);
        dcaFacet.setRouter(BASE_UNISWAP_V2_ROUTER);

        console.log("Router successfully set!");
    }
}
