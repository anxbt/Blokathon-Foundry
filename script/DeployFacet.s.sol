//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseScript} from "script/Base.s.sol";
import {console} from "forge-std/console.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {TestFacet} from "src/facets/utilityFacets/TestFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";

contract DeployFacetScript is BaseScript {
    address internal constant DIAMOND_ADDRESS = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
    function run() public broadcaster {
        setUp();
        TestFacet testFacet = new TestFacet();
        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = TestFacet.test1.selector;
        functionSelectors[1] = TestFacet.test2.selector;

        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        DiamondCutFacet(DIAMOND_ADDRESS).diamondCut(facetCuts, address(0), "");
        console.log("TestFacet deployed to: ", address(testFacet));
    }
}