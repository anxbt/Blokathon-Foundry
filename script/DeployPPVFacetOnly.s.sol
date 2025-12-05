// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseScript} from "script/Base.s.sol";
import {console} from "forge-std/console.sol";

import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {PPVFacet} from "src/facets/utilityFacets/ppv/PPVFacet.sol";
import {IPPV} from "src/facets/utilityFacets/ppv/IPPV.sol";

/**
 * @title DeployPPVFacetOnly
 * @notice Deploys ONLY the PPVFacet and adds it to existing Diamond
 * @dev Use this if you already have a Diamond deployed
 *
 * Usage:
 *   1. Set DIAMOND_ADDRESS below to your existing Diamond
 *   2. Run: forge script script/DeployPPVFacetOnly.s.sol \
 *            --rpc-url https://mainnet.base.org \
 *            --private-key $PRIVATE_KEY \
 *            --broadcast --verify
 */
contract DeployPPVFacetOnlyScript is BaseScript {
    // ⚠️ UPDATE THIS with your existing Diamond address!
    address constant DIAMOND_ADDRESS = address(0); // <-- CHANGE THIS!

    // Base Mainnet - USDC
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Insurance fee: 2% (200 basis points)
    uint16 constant INSURANCE_FEE_BPS = 200;

    function run() public broadcaster {
        setUp();

        require(
            DIAMOND_ADDRESS != address(0),
            "Please set DIAMOND_ADDRESS in the script!"
        );

        console.log("========================================");
        console.log("Deploying PPVFacet to Existing Diamond");
        console.log("========================================");
        console.log("Network:        Base Mainnet");
        console.log("Diamond:        ", DIAMOND_ADDRESS);
        console.log("Deployer:       ", deployer);
        console.log("");

        // ====================================================================
        // Step 1: Deploy PPVFacet
        // ====================================================================

        console.log("Step 1: Deploying PPVFacet...");
        PPVFacet ppvFacet = new PPVFacet();
        console.log("  PPVFacet:     ", address(ppvFacet));
        console.log("");

        // ====================================================================
        // Step 2: Prepare Facet Cut
        // ====================================================================

        console.log("Step 2: Preparing facet cut...");

        bytes4[] memory ppvSelectors = new bytes4[](13);
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
        ppvSelectors[12] = IPPV.setPaused.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(ppvFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ppvSelectors
        });

        console.log("  Prepared 13 function selectors");
        console.log("");

        // ====================================================================
        // Step 3: Add to Diamond
        // ====================================================================

        console.log("Step 3: Adding PPVFacet to Diamond...");
        DiamondCutFacet(DIAMOND_ADDRESS).diamondCut(cuts, address(0), "");
        console.log("  PPVFacet added successfully!");
        console.log("");

        // ====================================================================
        // Step 4: Configure PPV
        // ====================================================================

        console.log("Step 4: Configuring PPV...");
        IPPV ppv = IPPV(DIAMOND_ADDRESS);

        ppv.setDepositToken(USDC);
        console.log("  Deposit token: ", USDC, "(USDC)");

        ppv.setInsuranceFeeBps(INSURANCE_FEE_BPS);
        console.log("  Insurance fee: ", INSURANCE_FEE_BPS, "bps (2%)");
        console.log("");

        // ====================================================================
        // Summary
        // ====================================================================

        console.log("========================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("Contract Addresses:");
        console.log("-------------------");
        console.log("Diamond:           ", DIAMOND_ADDRESS);
        console.log("PPVFacet:          ", address(ppvFacet));
        console.log("");
        console.log("Configuration:");
        console.log("-------------------");
        console.log("Owner:             ", deployer);
        console.log("Deposit Token:     ", USDC);
        console.log("Insurance Fee:     ", INSURANCE_FEE_BPS, "bps");
        console.log("");
        console.log("BaseScan URLs:");
        console.log("-------------------");
        console.log("Diamond:           ", _url(DIAMOND_ADDRESS));
        console.log("PPVFacet:          ", _url(address(ppvFacet)));
        console.log("");
        console.log("Next Steps:");
        console.log("-------------------");
        console.log("1. Verify PPVFacet on BaseScan");
        console.log("2. Fund reserve: IPPV(diamond).fundReserve(amount)");
        console.log("3. Test deposit with USDC");
        console.log("========================================");
    }

    function _url(address addr) internal pure returns (string memory) {
        return
            string.concat("https://basescan.org/address/", _addrToString(addr));
    }

    function _addrToString(
        address _addr
    ) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
