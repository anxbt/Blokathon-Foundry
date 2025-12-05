// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "src/Diamond.sol";
import "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import "src/facets/utilityFacets/dca/DCAFacet.sol";
import "src/facets/utilityFacets/dca/IDCAFacet.sol";
import "src/facets/utilityFacets/garden/GardenFacet.sol";
import "src/facets/utilityFacets/garden/GardenDCAFacet.sol";
import "src/interfaces/IERC173.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GardenFacetTest is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    DCAFacet dcaFacet;
    GardenFacet gardenFacet;
    GardenDCAFacet gardenDCAFacet;

    address owner = address(0x123);
    address user = address(0x456);
    address nonOwner = address(0x789);

    // Base Mainnet Constants
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; // DAI on Base
    address constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address constant USDC_WHALE = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A;

    function setUp() public {
        // Fork Base Mainnet
        try vm.envString("RPC_URL_BASE") returns (string memory url) {
            vm.createSelectFork(url);
        } catch {
            // Use CLI --fork-url
        }
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        dcaFacet = new DCAFacet();
        gardenFacet = new GardenFacet();
        gardenDCAFacet = new GardenDCAFacet();

        // Prepare cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](6);

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

        // GardenFacet
        bytes4[] memory gardenSelectors = new bytes4[](5);
        gardenSelectors[0] = GardenFacet.createGarden.selector;
        gardenSelectors[1] = GardenFacet.updateGarden.selector;
        gardenSelectors[2] = GardenFacet.removeGarden.selector;
        gardenSelectors[3] = GardenFacet.getGarden.selector;
        gardenSelectors[4] = GardenFacet.getNextGardenId.selector;
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(gardenFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gardenSelectors
        });

        // GardenDCAFacet
        bytes4[] memory gardenDCASelectors = new bytes4[](4);
        gardenDCASelectors[0] = GardenDCAFacet.createGardenPlan.selector;
        gardenDCASelectors[1] = GardenDCAFacet.executeGardenStep.selector;
        gardenDCASelectors[2] = GardenDCAFacet.getPlanGarden.selector;
        gardenDCASelectors[3] = GardenDCAFacet.isGardenPlan.selector;
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(gardenDCAFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gardenDCASelectors
        });

        // Deploy Diamond
        vm.prank(owner);
        diamond = new Diamond(owner, cuts);

        // Set Router
        vm.prank(owner);
        IDCAFacet(address(diamond)).setRouter(ROUTER);

        // Fund User with USDC
        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(user, 100 * 1e6);
    }

    // ========================================================================
    // GardenFacet Tests
    // ========================================================================

    function testCreateGarden() public {
        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = DAI;

        uint16[] memory weights = new uint16[](2);
        weights[0] = 6000; // 60%
        weights[1] = 4000; // 40%

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "ETH-BTC Basket",
            assets,
            weights
        );

        (
            string memory name,
            address[] memory returnedAssets,
            uint16[] memory returnedWeights,
            bool active
        ) = GardenFacet(address(diamond)).getGarden(gardenId);

        assertEq(name, "ETH-BTC Basket");
        assertEq(returnedAssets.length, 2);
        assertEq(returnedAssets[0], WETH);
        assertEq(returnedAssets[1], DAI);
        assertEq(returnedWeights[0], 6000);
        assertEq(returnedWeights[1], 4000);
        assertTrue(active);
    }

    function testCreateGardenOnlyOwner() public {
        address[] memory assets = new address[](1);
        assets[0] = WETH;

        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;

        vm.prank(nonOwner);
        vm.expectRevert(Diamond_UnauthorizedCaller.selector);
        GardenFacet(address(diamond)).createGarden("Test", assets, weights);
    }

    function testCreateGardenInvalidWeights() public {
        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = DAI;

        uint16[] memory weights = new uint16[](2);
        weights[0] = 5000;
        weights[1] = 4000; // Sum = 9000, not 10000

        vm.prank(owner);
        vm.expectRevert(Garden_InvalidWeights.selector);
        GardenFacet(address(diamond)).createGarden(
            "Bad Weights",
            assets,
            weights
        );
    }

    function testCreateGardenMismatchedArrays() public {
        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = DAI;

        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;

        vm.prank(owner);
        vm.expectRevert(Garden_ArrayLengthMismatch.selector);
        GardenFacet(address(diamond)).createGarden(
            "Mismatched",
            assets,
            weights
        );
    }

    function testUpdateGarden() public {
        // Create garden
        address[] memory assets = new address[](1);
        assets[0] = WETH;
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "Original",
            assets,
            weights
        );

        // Update garden
        address[] memory newAssets = new address[](2);
        newAssets[0] = WETH;
        newAssets[1] = DAI;
        uint16[] memory newWeights = new uint16[](2);
        newWeights[0] = 7000;
        newWeights[1] = 3000;

        vm.prank(owner);
        GardenFacet(address(diamond)).updateGarden(
            gardenId,
            newAssets,
            newWeights
        );

        (
            ,
            address[] memory returnedAssets,
            uint16[] memory returnedWeights,

        ) = GardenFacet(address(diamond)).getGarden(gardenId);

        assertEq(returnedAssets.length, 2);
        assertEq(returnedWeights[0], 7000);
    }

    function testRemoveGarden() public {
        address[] memory assets = new address[](1);
        assets[0] = WETH;
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "ToRemove",
            assets,
            weights
        );

        vm.prank(owner);
        GardenFacet(address(diamond)).removeGarden(gardenId);

        (, , , bool active) = GardenFacet(address(diamond)).getGarden(gardenId);
        assertFalse(active);
    }

    // ========================================================================
    // GardenDCAFacet Tests
    // ========================================================================

    function testCreateGardenPlan() public {
        // Create garden first
        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = DAI;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 6000;
        weights[1] = 4000;

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "Test Garden",
            assets,
            weights
        );

        // User creates garden plan
        uint256 amountPerInterval = 1 * 1e6;
        uint256 intervalSeconds = 3600;
        uint256 totalIntervals = 5;

        vm.startPrank(user);
        IERC20(USDC).approve(
            address(diamond),
            amountPerInterval * totalIntervals
        );

        uint256 planId = GardenDCAFacet(address(diamond)).createGardenPlan(
            USDC,
            amountPerInterval,
            intervalSeconds,
            totalIntervals,
            gardenId
        );
        vm.stopPrank();

        // Verify plan
        uint256 linkedGarden = GardenDCAFacet(address(diamond)).getPlanGarden(
            planId
        );
        assertEq(linkedGarden, gardenId);
        assertTrue(GardenDCAFacet(address(diamond)).isGardenPlan(planId));
    }

    function testCreateGardenPlanInactiveGarden() public {
        // Create and remove garden
        address[] memory assets = new address[](1);
        assets[0] = WETH;
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "Inactive",
            assets,
            weights
        );

        vm.prank(owner);
        GardenFacet(address(diamond)).removeGarden(gardenId);

        // Try to create plan with inactive garden
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), 5 * 1e6);

        vm.expectRevert(GardenDCA_GardenNotActive.selector);
        GardenDCAFacet(address(diamond)).createGardenPlan(
            USDC,
            1e6,
            3600,
            5,
            gardenId
        );
        vm.stopPrank();
    }

    function testExecuteGardenStep() public {
        // Create garden
        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = DAI;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 6000; // 60%
        weights[1] = 4000; // 40%

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "DCA Garden",
            assets,
            weights
        );

        // Create plan
        uint256 amountPerInterval = 10 * 1e6; // 10 USDC
        uint256 intervalSeconds = 3600;
        uint256 totalIntervals = 2;

        vm.startPrank(user);
        IERC20(USDC).approve(
            address(diamond),
            amountPerInterval * totalIntervals
        );
        uint256 planId = GardenDCAFacet(address(diamond)).createGardenPlan(
            USDC,
            amountPerInterval,
            intervalSeconds,
            totalIntervals,
            gardenId
        );
        vm.stopPrank();

        // Warp time
        vm.warp(block.timestamp + intervalSeconds);

        // Prepare swap data for each asset
        // 60% of 10 USDC = 6 USDC for WETH
        // 40% of 10 USDC = 4 USDC for DAI
        address[] memory path1 = new address[](2);
        path1[0] = USDC;
        path1[1] = WETH;

        address[] memory path2 = new address[](2);
        path2[0] = USDC;
        path2[1] = DAI;

        bytes[] memory swapData = new bytes[](2);
        swapData[0] = abi.encodeWithSignature(
            "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)",
            6 * 1e6,
            0,
            path1,
            user,
            block.timestamp + 600
        );
        swapData[1] = abi.encodeWithSignature(
            "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)",
            4 * 1e6,
            0,
            path2,
            user,
            block.timestamp + 600
        );

        uint256 userWethBefore = IERC20(WETH).balanceOf(user);

        // Execute step
        GardenDCAFacet(address(diamond)).executeGardenStep(planId, swapData);

        uint256 userWethAfter = IERC20(WETH).balanceOf(user);
        assertTrue(userWethAfter > userWethBefore, "User should receive WETH");

        // Verify plan state
        IDCAFacet.ViewPlan memory plan = IDCAFacet(address(diamond)).getPlan(
            planId
        );
        assertEq(plan.executedIntervals, 1);
        assertTrue(plan.active);
    }

    function testExecuteGardenStepTooEarly() public {
        // Create garden
        address[] memory assets = new address[](1);
        assets[0] = WETH;
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10000;

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "Early",
            assets,
            weights
        );

        // Create plan
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), 5 * 1e6);
        uint256 planId = GardenDCAFacet(address(diamond)).createGardenPlan(
            USDC,
            1e6,
            3600,
            5,
            gardenId
        );
        vm.stopPrank();

        // Try to execute without waiting
        bytes[] memory swapData = new bytes[](1);
        swapData[0] = "";

        vm.expectRevert(GardenDCA_TooEarly.selector);
        GardenDCAFacet(address(diamond)).executeGardenStep(planId, swapData);
    }

    function testExecuteGardenStepSwapDataMismatch() public {
        // Create garden with 2 assets
        address[] memory assets = new address[](2);
        assets[0] = WETH;
        assets[1] = DAI;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 5000;
        weights[1] = 5000;

        vm.prank(owner);
        uint256 gardenId = GardenFacet(address(diamond)).createGarden(
            "Mismatch",
            assets,
            weights
        );

        // Create plan
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), 5 * 1e6);
        uint256 planId = GardenDCAFacet(address(diamond)).createGardenPlan(
            USDC,
            1e6,
            3600,
            5,
            gardenId
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 3600);

        // Provide wrong number of swap data (1 instead of 2)
        bytes[] memory swapData = new bytes[](1);
        swapData[0] = "";

        vm.expectRevert(GardenDCA_SwapDataMismatch.selector);
        GardenDCAFacet(address(diamond)).executeGardenStep(planId, swapData);
    }
}
