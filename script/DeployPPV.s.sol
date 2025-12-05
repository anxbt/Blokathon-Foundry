// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseScript} from "script/Base.s.sol";
import {console} from "forge-std/console.sol";

// Diamond Contracts
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {
    DiamondLoupeFacet
} from "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {
    OwnershipFacet
} from "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {IDiamondLoupe} from "src/facets/baseFacets/loupe/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {IERC165} from "src/interfaces/IERC165.sol";

// PPV Facet
import {PPVFacet} from "src/facets/utilityFacets/ppv/PPVFacet.sol";
import {IPPV} from "src/facets/utilityFacets/ppv/IPPV.sol";

/**
 * @title DeployPPV
 * @notice Deploys Diamond + Principal Protected Vault Facet to Base mainnet
 * @dev This is the main hackathon deployment script
 *
 * Usage:
 *   forge script script/DeployPPV.s.sol \
 *     --rpc-url https://mainnet.base.org \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast --verify
 */
contract DeployPPVScript is BaseScript {
    // Base Mainnet - USDC
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Insurance fee: 2% (200 basis points)
    uint16 constant INSURANCE_FEE_BPS = 200;

    function run() public broadcaster {
        setUp();

        console.log("========================================");
        console.log("Deploying Principal Protected Vault");
        console.log("========================================");
        console.log("Network: Base Mainnet");
        console.log("Deployer:", deployer);
        console.log("");

        // ====================================================================
        // Step 1: Deploy Base Facets
        // ====================================================================

        console.log("Step 1: Deploying base facets...");
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();

        console.log("  DiamondCutFacet:   ", address(diamondCutFacet));
        console.log("  DiamondLoupeFacet: ", address(diamondLoupeFacet));
        console.log("  OwnershipFacet:    ", address(ownershipFacet));
        console.log("");

        // ====================================================================
        // Step 2: Deploy PPV Facet
        // ====================================================================

        console.log("Step 2: Deploying PPV facet...");
        PPVFacet ppvFacet = new PPVFacet();
        console.log("  PPVFacet:          ", address(ppvFacet));
        console.log("");

        // ====================================================================
        // Step 3: Prepare Facet Cuts
        // ====================================================================

        console.log("Step 3: Preparing facet cuts...");
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);

        // DiamondCut Facet
        bytes4[] memory cutSelectors = new bytes4[](1);
        cutSelectors[0] = IDiamondCut.diamondCut.selector;
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        // DiamondLoupe Facet
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

        // Ownership Facet
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = IERC173.owner.selector;
        ownershipSelectors[1] = IERC173.transferOwnership.selector;
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        // PPV Facet
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
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(ppvFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ppvSelectors
        });

        console.log("  Prepared 4 facets with selectors");
        console.log("");

        // ====================================================================
        // Step 4: Deploy Diamond
        // ====================================================================

        console.log("Step 4: Deploying Diamond...");
        Diamond diamond = new Diamond(deployer, cuts);
        console.log("  Diamond:           ", address(diamond));
        console.log("");

        // ====================================================================
        // Step 5: Configure PPV
        // ====================================================================

        console.log("Step 5: Configuring PPV...");
        IPPV ppv = IPPV(address(diamond));

        ppv.setDepositToken(USDC);
        console.log("  Deposit token:     ", USDC, "(USDC)");

        ppv.setInsuranceFeeBps(INSURANCE_FEE_BPS);
        console.log("  Insurance fee:     ", INSURANCE_FEE_BPS, "bps (2%)");
        console.log("");

        // ====================================================================
        // Step 6: Verification Info
        // ====================================================================

        console.log("========================================");
        console.log("DEPLOYMENT COMPLETE!");
        console.log("========================================");
        console.log("");
        console.log("Contract Addresses:");
        console.log("-------------------");
        console.log("Diamond:            ", address(diamond));
        console.log("DiamondCutFacet:    ", address(diamondCutFacet));
        console.log("DiamondLoupeFacet:  ", address(diamondLoupeFacet));
        console.log("OwnershipFacet:     ", address(ownershipFacet));
        console.log("PPVFacet:           ", address(ppvFacet));
        console.log("");
        console.log("Configuration:");
        console.log("-------------------");
        console.log("Owner:              ", deployer);
        console.log("Deposit Token:      ", USDC);
        console.log("Insurance Fee:      ", INSURANCE_FEE_BPS, "bps");
        console.log("");
        console.log("BaseScan URLs:");
        console.log("-------------------");
        console.log(
            "Diamond:            ",
            string.concat(
                "https://basescan.org/address/",
                _addressToString(address(diamond))
            )
        );
        console.log(
            "PPVFacet:           ",
            string.concat(
                "https://basescan.org/address/",
                _addressToString(address(ppvFacet))
            )
        );
        console.log("");
        console.log("Next Steps:");
        console.log("-------------------");
        console.log("1. Verify contracts on BaseScan (if not auto-verified)");
        console.log("2. Fund reserve: ppv.fundReserve(amount)");
        console.log("3. Test deposit: ppv.deposit(1000 * 1e6) // 1000 USDC");
        console.log("4. Add to README with BaseScan links");
        console.log("========================================");
    }

    // Helper function to convert address to string
    function _addressToString(
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
