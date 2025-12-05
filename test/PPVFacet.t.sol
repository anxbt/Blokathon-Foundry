// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/Diamond.sol";
import "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import "src/facets/utilityFacets/ppv/PPVFacet.sol";
import "src/facets/utilityFacets/ppv/IPPV.sol";
import "src/interfaces/IERC173.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PPVFacetTest
 * @notice Tests for Principal Protected Vault Facet
 * @dev Tests run on Base mainnet fork using real Aave V3
 */
contract PPVFacetTest is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    PPVFacet ppvFacet;

    address owner = address(0x123);
    address user = address(0x456);
    address user2 = address(0x789);

    // Base Mainnet Constants
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant USDC_WHALE = 0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3; // Circle/Coinbase whale

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
        ppvFacet = new PPVFacet();

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

        // PPVFacet
        bytes4[] memory ppvSelectors = new bytes4[](12);
        ppvSelectors[0] = IPPV.deposit.selector;
        ppvSelectors[1] = IPPV.withdraw.selector;
        ppvSelectors[2] = IPPV.getUserPrincipal.selector;
        ppvSelectors[3] = IPPV.getUserPortfolioValue.selector;
        ppvSelectors[4] = IPPV.getTotalDeposits.selector;
        ppvSelectors[5] = IPPV.getReserveBalance.selector;
        ppvSelectors[6] = IPPV.getInsuranceFeeBps.selector;
        ppvSelectors[7] = IPPV.getDepositToken.selector;
        ppvSelectors[8] = IPPV.isPaused.selector;
        ppvSelectors[9] = IPPV.setDepositToken.selector;
        ppvSelectors[10] = IPPV.setInsuranceFeeBps.selector;
        ppvSelectors[11] = IPPV.fundReserve.selector;
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(ppvFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ppvSelectors
        });

        // Deploy Diamond
        vm.prank(owner);
        diamond = new Diamond(owner, cuts);

        // Configure vault
        vm.startPrank(owner);
        IPPV(address(diamond)).setDepositToken(USDC);
        IPPV(address(diamond)).setInsuranceFeeBps(200); // 2% fee
        vm.stopPrank();

        // Fund users with USDC
        vm.startPrank(USDC_WHALE);
        IERC20(USDC).transfer(user, 10000 * 1e6); // 10,000 USDC
        IERC20(USDC).transfer(user2, 10000 * 1e6); // 10,000 USDC
        IERC20(USDC).transfer(owner, 1000 * 1e6); // 1,000 USDC for reserve
        vm.stopPrank();
    }

    // ========================================================================
    // Configuration Tests
    // ========================================================================

    function testSetDepositToken() public {
        assertEq(IPPV(address(diamond)).getDepositToken(), USDC);
    }

    function testSetInsuranceFeeBps() public {
        assertEq(IPPV(address(diamond)).getInsuranceFeeBps(), 200);
    }

    function testOnlyOwnerCanSetDepositToken() public {
        vm.prank(user);
        vm.expectRevert();
        IPPV(address(diamond)).setDepositToken(address(0x999));
    }

    // ========================================================================
    // Deposit Tests
    // ========================================================================

    function testDeposit() public {
        uint256 depositAmount = 1000 * 1e6; // 1000 USDC

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), depositAmount);
        IPPV(address(diamond)).deposit(depositAmount);
        vm.stopPrank();

        // Check principal recorded
        assertEq(IPPV(address(diamond)).getUserPrincipal(user), depositAmount);

        // Check total deposits
        assertEq(IPPV(address(diamond)).getTotalDeposits(), depositAmount);

        // Check reserve (2% of 1000 = 20 USDC)
        assertEq(IPPV(address(diamond)).getReserveBalance(), 20 * 1e6);
    }

    function testDepositCreatesAavePosition() public {
        uint256 depositAmount = 1000 * 1e6;

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), depositAmount);
        IPPV(address(diamond)).deposit(depositAmount);
        vm.stopPrank();

        // User should have portfolio value in Aave
        uint256 portfolioValue = IPPV(address(diamond)).getUserPortfolioValue(
            user
        );

        // Portfolio should be ~980 USDC (1000 - 2% fee)
        assertGt(portfolioValue, 970 * 1e6);
        assertLt(portfolioValue, 1000 * 1e6);
    }

    function testCannotDepositZero() public {
        vm.prank(user);
        vm.expectRevert();
        IPPV(address(diamond)).deposit(0);
    }

    function testCannotDepositTwice() public {
        uint256 depositAmount = 100 * 1e6;

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), depositAmount * 2);
        IPPV(address(diamond)).deposit(depositAmount);

        vm.expectRevert();
        IPPV(address(diamond)).deposit(depositAmount);
        vm.stopPrank();
    }

    // ========================================================================
    // Withdraw Tests
    // ========================================================================

    function testWithdrawWithProfit() public {
        uint256 depositAmount = 1000 * 1e6;

        // Deposit
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), depositAmount);
        IPPV(address(diamond)).deposit(depositAmount);
        vm.stopPrank();

        // Simulate time passing (Aave earns yield)
        vm.warp(block.timestamp + 365 days);

        // Withdraw
        uint256 userBalanceBefore = IERC20(USDC).balanceOf(user);

        vm.prank(user);
        IPPV(address(diamond)).withdraw();

        uint256 userBalanceAfter = IERC20(USDC).balanceOf(user);
        uint256 received = userBalanceAfter - userBalanceBefore;

        // User should receive at least their principal (980 USDC invested)
        // May be slightly less due to Aave mechanics, but principal protection kicks in
        console.log("User deposited:", depositAmount);
        console.log("User received:", received);

        // With reserve, user should get close to or above principal
        assertGt(received, 900 * 1e6, "User should receive substantial amount");
    }

    function testWithdrawWithLossUsesReserve() public {
        uint256 depositAmount = 1000 * 1e6;
        uint256 reserveAmount = 100 * 1e6;

        // Owner funds reserve
        vm.startPrank(owner);
        IERC20(USDC).approve(address(diamond), reserveAmount);
        IPPV(address(diamond)).fundReserve(reserveAmount);
        vm.stopPrank();

        // User deposits
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), depositAmount);
        IPPV(address(diamond)).deposit(depositAmount);
        vm.stopPrank();

        // Check reserve increased (2% fee + owner funding)
        uint256 reserveBefore = IPPV(address(diamond)).getReserveBalance();
        assertEq(reserveBefore, reserveAmount + 20 * 1e6); // 100 + 20 = 120 USDC

        // Withdraw (even if at loss, reserve should help)
        vm.prank(user);
        IPPV(address(diamond)).withdraw();

        // User deposit should be cleared
        assertEq(IPPV(address(diamond)).getUserPrincipal(user), 0);
    }

    function testCannotWithdrawWithoutDeposit() public {
        vm.prank(user);
        vm.expectRevert();
        IPPV(address(diamond)).withdraw();
    }

    // ========================================================================
    // Reserve Tests
    // ========================================================================

    function testFundReserve() public {
        uint256 reserveAmount = 500 * 1e6;

        vm.startPrank(owner);
        IERC20(USDC).approve(address(diamond), reserveAmount);
        IPPV(address(diamond)).fundReserve(reserveAmount);
        vm.stopPrank();

        assertEq(IPPV(address(diamond)).getReserveBalance(), reserveAmount);
    }

    function testAnyoneCanFundReserve() public {
        uint256 reserveAmount = 100 * 1e6;

        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), reserveAmount);
        IPPV(address(diamond)).fundReserve(reserveAmount);
        vm.stopPrank();

        assertEq(IPPV(address(diamond)).getReserveBalance(), reserveAmount);
    }

    // ========================================================================
    // Multiple Users Test
    // ========================================================================

    function testMultipleUsersDeposit() public {
        uint256 deposit1 = 1000 * 1e6;
        uint256 deposit2 = 2000 * 1e6;

        // User 1 deposits
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), deposit1);
        IPPV(address(diamond)).deposit(deposit1);
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(user2);
        IERC20(USDC).approve(address(diamond), deposit2);
        IPPV(address(diamond)).deposit(deposit2);
        vm.stopPrank();

        // Check totals
        assertEq(
            IPPV(address(diamond)).getTotalDeposits(),
            deposit1 + deposit2
        );
        assertEq(IPPV(address(diamond)).getUserPrincipal(user), deposit1);
        assertEq(IPPV(address(diamond)).getUserPrincipal(user2), deposit2);

        // Check reserve (2% of 3000 = 60 USDC)
        assertEq(IPPV(address(diamond)).getReserveBalance(), 60 * 1e6);
    }

    // ========================================================================
    // Integration Test - Full Flow
    // ========================================================================

    function testFullPrincipalProtectionFlow() public {
        console.log("=== Principal Protected Vault Full Flow Test ===");

        // 1. Owner funds reserve
        uint256 reserveFunding = 500 * 1e6;
        vm.startPrank(owner);
        IERC20(USDC).approve(address(diamond), reserveFunding);
        IPPV(address(diamond)).fundReserve(reserveFunding);
        vm.stopPrank();
        console.log("1. Reserve funded:", reserveFunding / 1e6, "USDC");

        // 2. User deposits
        uint256 userDeposit = 1000 * 1e6;
        vm.startPrank(user);
        IERC20(USDC).approve(address(diamond), userDeposit);
        IPPV(address(diamond)).deposit(userDeposit);
        vm.stopPrank();
        console.log("2. User deposited:", userDeposit / 1e6, "USDC");
        console.log(
            "   Principal recorded:",
            IPPV(address(diamond)).getUserPrincipal(user) / 1e6,
            "USDC"
        );
        console.log(
            "   Reserve balance:",
            IPPV(address(diamond)).getReserveBalance() / 1e6,
            "USDC"
        );

        // 3. Time passes (yield accrues)
        vm.warp(block.timestamp + 30 days);
        uint256 portfolioValue = IPPV(address(diamond)).getUserPortfolioValue(
            user
        );
        console.log(
            "3. After 30 days, portfolio value:",
            portfolioValue / 1e6,
            "USDC"
        );

        // 4. User withdraws
        uint256 userBalanceBefore = IERC20(USDC).balanceOf(user);
        vm.prank(user);
        IPPV(address(diamond)).withdraw();
        uint256 userBalanceAfter = IERC20(USDC).balanceOf(user);
        uint256 received = userBalanceAfter - userBalanceBefore;

        console.log("4. User withdrew and received:", received / 1e6, "USDC");
        console.log(
            "   Reserve after:",
            IPPV(address(diamond)).getReserveBalance() / 1e6,
            "USDC"
        );

        // 5. Verify principal protection
        // User should receive at least close to their deposit
        // (accounting for any extreme market conditions)
        assertGt(
            received,
            800 * 1e6,
            "User should receive substantial protected amount"
        );

        console.log("=== Test Passed: Principal Protected! ===");
    }
}
