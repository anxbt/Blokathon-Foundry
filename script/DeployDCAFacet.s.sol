// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseScript} from "script/Base.s.sol";
import {console} from "forge-std/console.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {DCAFacet} from "src/facets/utilityFacets/dca/DCAFacet.sol";
import {IDCAFacet} from "src/facets/utilityFacets/dca/IDCAFacet.sol";

/**
 * @title DeployDCAFacet
 * @notice Deploys and adds the DCA (Dollar Cost Averaging) facet to the Diamond
 * @dev This script:
 *      1. Deploys the DCAFacet contract
 *      2. Adds all DCA functions to the Diamond via diamondCut
 *      3. Sets the Uniswap V2 router address (BASE chain)
 *
 * Usage:
 * forge script script/DeployDCAFacet.s.sol \
 *   --rpc-url $RPC_URL_BASE \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast
 */
contract DeployDCAFacetScript is BaseScript {
    // IMPORTANT: Update this with your deployed Diamond address
    address internal constant DIAMOND_ADDRESS = address(0); // <-- UPDATE THIS!

    // BASE chain Uniswap V2-style router
    address constant BASE_UNISWAP_V2_ROUTER =
        0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

    function run() public broadcaster {
        setUp();

        require(
            DIAMOND_ADDRESS != address(0),
            "Please set DIAMOND_ADDRESS in the script"
        );

        console.log("Deploying DCAFacet...");
        console.log("Diamond address:", DIAMOND_ADDRESS);
        console.log("Deployer (should be Diamond owner):", deployer);

        // Deploy DCAFacet
        DCAFacet dcaFacet = new DCAFacet();
        console.log("DCAFacet deployed to:", address(dcaFacet));

        // Prepare facet cut
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);

        // Add function selectors for DCAFacet
        bytes4[] memory functionSelectors = new bytes4[](7);
        functionSelectors[0] = IDCAFacet.createPlan.selector;
        functionSelectors[1] = IDCAFacet.cancelPlan.selector;
        functionSelectors[2] = IDCAFacet.executeStep.selector;
        functionSelectors[3] = IDCAFacet.setRouter.selector;
        functionSelectors[4] = IDCAFacet.getRouter.selector;
        functionSelectors[5] = IDCAFacet.getPlan.selector;
        functionSelectors[6] = IDCAFacet.getUserPlans.selector;

        // Create facet cut
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(dcaFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // Cut diamond (add DCA facet)
        console.log("Adding DCAFacet to Diamond...");
        DiamondCutFacet(DIAMOND_ADDRESS).diamondCut(facetCuts, address(0), "");
        console.log("DCAFacet successfully added to Diamond!");

        // Set the router address
        console.log("Setting Uniswap V2 router:", BASE_UNISWAP_V2_ROUTER);
        IDCAFacet(DIAMOND_ADDRESS).setRouter(BASE_UNISWAP_V2_ROUTER);
        console.log("Router successfully set!");

        // Verify router was set correctly
        address setRouterAddress = IDCAFacet(DIAMOND_ADDRESS).getRouter();
        require(
            setRouterAddress == BASE_UNISWAP_V2_ROUTER,
            "Router verification failed!"
        );
        console.log("Router verified:", setRouterAddress);

        console.log("\n=== Deployment Summary ===");
        console.log("Diamond Address:", DIAMOND_ADDRESS);
        console.log("DCAFacet Address:", address(dcaFacet));
        console.log("Router Address:", BASE_UNISWAP_V2_ROUTER);
        console.log("========================\n");
    }
}
