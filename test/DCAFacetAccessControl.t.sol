// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/Diamond.sol";
import "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import "src/facets/utilityFacets/dca/DCAFacet.sol";
import "src/facets/utilityFacets/dca/IDCAFacet.sol";
import "src/interfaces/IERC173.sol";

contract DCAFacetAccessControlTest is Test {
    Diamond diamond;
    DCAFacet dcaFacet;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;

    address owner = address(0x123);
    address nonOwner = address(0x456);
    address router = address(0x789);

    function setUp() public {
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        dcaFacet = new DCAFacet();

        // Prepare cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // DiamondCut
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = IDiamondCut.diamondCut.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        // DiamondLoupe
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = IDiamondLoupe.facets.selector;
        loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Ownership
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = IERC173.owner.selector;
        ownershipSelectors[1] = IERC173.transferOwnership.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        // DCAFacet
        bytes4[] memory dcaSelectors = new bytes4[](7);
        dcaSelectors[0] = IDCAFacet.createPlan.selector;
        dcaSelectors[1] = IDCAFacet.cancelPlan.selector;
        dcaSelectors[2] = IDCAFacet.executeStep.selector;
        dcaSelectors[3] = IDCAFacet.setRouter.selector;
        dcaSelectors[4] = IDCAFacet.getRouter.selector;
        dcaSelectors[5] = IDCAFacet.getPlan.selector;
        dcaSelectors[6] = IDCAFacet.getUserPlans.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(dcaFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: dcaSelectors
        });

        // Deploy Diamond with owner
        vm.prank(owner);
        diamond = new Diamond(owner, cuts);
    }

    function testSetRouterAsOwner() public {
        vm.startPrank(owner);
        IDCAFacet(address(diamond)).setRouter(router);
        address setRouter = IDCAFacet(address(diamond)).getRouter();
        assertEq(setRouter, router, "Router should be set correctly by owner");
        vm.stopPrank();
    }

    function testSetRouterAsNonOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(Diamond_UnauthorizedCaller.selector);
        IDCAFacet(address(diamond)).setRouter(router);
        vm.stopPrank();
    }

    function testSetRouterRevertMessage() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(Diamond_UnauthorizedCaller.selector);
        IDCAFacet(address(diamond)).setRouter(router);
        vm.stopPrank();
    }
}
