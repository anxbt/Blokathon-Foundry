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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DCAFacetFullFlowTest is Test {
    Diamond diamond;
    DCAFacet dcaFacet;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;

    address owner = address(0x123);
    address user = address(0x456);

    // Base Mainnet Constants
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address constant USDC_WHALE = 0x3304E22DDaa22bCdC5fCa2269b418046aE7b566A; // A known USDC holder on Base

    function setUp() public {
        // Fork Base Mainnet

        // Fork Base Mainnet
        // Use a try-catch block or check if env var exists, but for simplicity in this test environment:
        // We will use the URL passed via CLI --fork-url, so we don't need to create a new fork here
        // unless we want to explicitly switch.
        // If running with --fork-url, vm.createSelectFork is not strictly necessary if we just want to run on that fork.
        // However, to be robust:
        try vm.envString("RPC_URL_BASE") returns (string memory url) {
            vm.createSelectFork(url);
        } catch {
            // If env var is missing, assume we are already on a fork (via CLI) or use a public one
            // vm.createSelectFork("https://mainnet.base.org");
        }
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

        // Deploy Diamond
        vm.prank(owner);
        diamond = new Diamond(owner, cuts);

        // Set Router
        vm.prank(owner);
        IDCAFacet(address(diamond)).setRouter(ROUTER);

        // Fund User with USDC
        vm.prank(USDC_WHALE);
        IERC20(USDC).transfer(user, 100 * 1e6); // 100 USDC
    }

    function testFullDCAFlow() public {
        uint256 amountPerInterval = 1 * 1e6; // 1 USDC
        uint256 intervalSeconds = 3600; // 1 hour
        uint256 totalIntervals = 5;
        uint256 totalAmount = amountPerInterval * totalIntervals;

        // 1. Approve Token Spending
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), totalAmount);

        // 2. Create DCA Plan
        uint256 planId = IDCAFacet(address(diamond)).createPlan(
            USDC,
            WETH,
            amountPerInterval,
            intervalSeconds,
            totalIntervals
        );
        vm.stopPrank();

        // Verify Plan Creation
        IDCAFacet.ViewPlan memory plan = IDCAFacet(address(diamond)).getPlan(
            planId
        );
        assertEq(plan.user, user);
        assertEq(plan.tokenIn, USDC);
        assertEq(plan.tokenOut, WETH);
        assertEq(plan.amountPerInterval, amountPerInterval);
        assertEq(plan.totalIntervals, totalIntervals);
        assertEq(plan.executedIntervals, 0);
        assertEq(plan.active, true);

        // Verify Balances
        assertEq(IERC20(USDC).balanceOf(address(diamond)), totalAmount);

        // 3. Execute Steps
        for (uint256 i = 0; i < totalIntervals; i++) {
            // Wait for interval
            vm.warp(plan.nextExecutionTimestamp + (i * intervalSeconds));

            // Prepare Swap Data
            address[] memory path = new address[](2);
            path[0] = USDC;
            path[1] = WETH;

            bytes memory swapData = abi.encodeWithSignature(
                "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)",
                amountPerInterval,
                0, // minAmountOut
                path,
                user,
                block.timestamp + 600
            );

            uint256 userWethBefore = IERC20(WETH).balanceOf(user);

            // Execute Step
            IDCAFacet(address(diamond)).executeStep(planId, swapData);

            // Verify Step
            plan = IDCAFacet(address(diamond)).getPlan(planId);
            assertEq(plan.executedIntervals, i + 1);

            uint256 userWethAfter = IERC20(WETH).balanceOf(user);
            assertTrue(
                userWethAfter > userWethBefore,
                "User should receive WETH"
            );
        }

        // 4. Verify Final State
        plan = IDCAFacet(address(diamond)).getPlan(planId);
        assertEq(plan.executedIntervals, totalIntervals);
        assertEq(plan.active, false);
        assertEq(IERC20(USDC).balanceOf(address(diamond)), 0);
    }

    function testCancellation() public {
        uint256 amountPerInterval = 1 * 1e6;
        uint256 intervalSeconds = 3600;
        uint256 totalIntervals = 5;
        uint256 totalAmount = amountPerInterval * totalIntervals;

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), totalAmount);
        uint256 planId = IDCAFacet(address(diamond)).createPlan(
            USDC,
            WETH,
            amountPerInterval,
            intervalSeconds,
            totalIntervals
        );

        // Execute 1 step
        vm.warp(block.timestamp + intervalSeconds);
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = WETH;
        bytes memory swapData = abi.encodeWithSignature(
            "swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256,uint256,address[],address,uint256)",
            amountPerInterval,
            0,
            path,
            user,
            block.timestamp + 600
        );

        // Temporarily stop prank to execute as random executor
        vm.stopPrank();
        IDCAFacet(address(diamond)).executeStep(planId, swapData);

        // Resume user prank to cancel
        vm.startPrank(user);

        uint256 userUsdcBefore = IERC20(USDC).balanceOf(user);

        // Cancel Plan
        IDCAFacet(address(diamond)).cancelPlan(planId);

        uint256 userUsdcAfter = IERC20(USDC).balanceOf(user);
        uint256 expectedRefund = (totalIntervals - 1) * amountPerInterval;

        assertEq(
            userUsdcAfter - userUsdcBefore,
            expectedRefund,
            "Should refund remaining amount"
        );

        IDCAFacet.ViewPlan memory plan = IDCAFacet(address(diamond)).getPlan(
            planId
        );
        assertEq(plan.active, false);

        vm.stopPrank();
    }
}
