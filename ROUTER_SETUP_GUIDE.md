# Setting the Uniswap V2 Router in Your DCA Facet

## Router Address for BASE Chain
```
0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24
```

## How the Router is Stored in the Diamond

The router address is stored in the **DCAFacetStorage** using the Diamond storage pattern:

### Storage Location
📁 `src/facets/utilityFacets/dca/DCAFacetStorage.sol`

```solidity
struct Layout {
    mapping(uint256 => Plan) plans;
    mapping(address => uint256[]) userPlans;
    uint256 nextPlanId;
    address swapRouter;  // <-- Router stored here
    mapping(address => bool) allowedTokenIn;
}
```

The storage uses a **namespaced storage slot** (`keccak256("dca.facet.storage")`) to prevent collisions with other facets.

---

## How to Set the Router Address

You have **3 options** to set the router:

### ✅ Option 1: Deploy DCA Facet + Set Router in One Script (RECOMMENDED)

Use the comprehensive deployment script that does everything:

```bash
# 1. Edit script/DeployDCAFacet.s.sol
# Update line 23: address internal constant DIAMOND_ADDRESS = 0xYourDiamondAddress;

# 2. Deploy on BASE
source .env
forge script script/DeployDCAFacet.s.sol \
  --rpc-url $RPC_URL_BASE \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $API_KEY_BASESCAN
```

This script will:
1. ✅ Deploy DCAFacet
2. ✅ Add it to your Diamond
3. ✅ Automatically set the router address
4. ✅ Print a summary

---

### Option 2: Set Router After Deployment (Manual)

If you already deployed the DCA facet, use the dedicated setter script:

```bash
# 1. Edit script/SetDCARouter.s.sol
# Update line 20: address constant DIAMOND_ADDRESS = 0xYourDiamondAddress;

# 2. Run the script
source .env
forge script script/SetDCARouter.s.sol \
  --rpc-url $RPC_URL_BASE \
  --private-key $PRIVATE_KEY \
  --broadcast
```

---

### Option 3: Use Cast (Command Line)

Set the router directly with `cast`:

```bash
source .env

# Replace DIAMOND_ADDRESS with your deployed Diamond
DIAMOND_ADDRESS=0xYourDiamondAddress

cast send $DIAMOND_ADDRESS \
  "setRouter(address)" 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL_BASE
```

---

## Verify Router is Set

Check that the router was set correctly:

```bash
# Query the storage directly (advanced)
DIAMOND_ADDRESS=0xYourDiamondAddress

# Calculate storage slot
STORAGE_SLOT=$(cast keccak "dca.facet.storage")
echo "DCA Storage Slot: $STORAGE_SLOT"

# Read swapRouter (3rd slot in the Layout struct after mappings and nextPlanId)
cast storage $DIAMOND_ADDRESS $STORAGE_SLOT --rpc-url $RPC_URL_BASE
```

Or read it via a view function if you add one to your DCAFacet:

```solidity
function getRouter() external view returns (address) {
    return DCAFacetStorage.layout().swapRouter;
}
```

---

## Important Security Notes

### ⚠️ Only Diamond Owner Can Set Router

The `setRouter()` function uses the `onlyDiamondOwner` modifier:

```solidity
function setRouter(address router) external override onlyDiamondOwner {
    require(router != address(0), "DCA: zero router");
    DCAFacetStorage.layout().swapRouter = router;
    emit RouterSet(router);
}
```

**This means:**
- ✅ Only the address that deployed the Diamond can call `setRouter()`
- ✅ Make sure you use the correct private key (the Diamond owner's key)
- ❌ Other users cannot change the router (good for security!)

### Events Emitted

When the router is set, an event is emitted:

```solidity
event RouterSet(address indexed router);
```

You can check transaction logs to verify the router was set correctly.

---

## Router Addresses for Other Chains

If you deploy on other chains, use these Uniswap V2-compatible routers:

| Chain | Router Address |
|-------|---------------|
| **BASE** | `0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24` |
| Ethereum | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| Arbitrum | `0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506` |
| Polygon | `0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff` (QuickSwap) |
| BSC | `0x10ED43C718714eb63d5aA57B78B54704E256024E` (PancakeSwap) |

Update the `BASE_UNISWAP_V2_ROUTER` constant in the scripts for different chains.

---

## Architecture Overview

```
User calls Diamond
     ↓
Diamond.fallback()
     ↓
Look up setRouter selector → DCAFacet
     ↓
delegatecall to DCAFacet.setRouter()
     ↓
Check onlyDiamondOwner modifier
     ↓
Write to DCAFacetStorage.layout().swapRouter
     ↓
Emit RouterSet event
```

The router is stored in **Diamond's storage context** but in a **namespaced slot** owned by DCAFacet.

---

## Quick Reference: File Locations

| File | Purpose |
|------|---------|
| `src/facets/utilityFacets/dca/DCAFacetStorage.sol` | Defines storage layout (includes `swapRouter`) |
| `src/facets/utilityFacets/dca/DCAFacet.sol` | Public `setRouter()` function |
| `script/DeployDCAFacet.s.sol` | Deploy facet + set router (all-in-one) |
| `script/SetDCARouter.s.sol` | Just set router (if already deployed) |

---

## Troubleshooting

### Error: "DCA: only owner"
- ✅ Make sure you're using the Diamond owner's private key
- ✅ Check who owns the Diamond: `cast call $DIAMOND_ADDRESS "owner()" --rpc-url $RPC_URL_BASE`

### Error: "DCA: zero router"
- ✅ Make sure the router address is not `0x0000000000000000000000000000000000000000`

### Error: "DCA: router unset" (during executeStep)
- ✅ Run the SetDCARouter script to set the router
- ✅ Or use the DeployDCAFacet script which sets it automatically

---

## Next Steps

After setting the router, you can:

1. ✅ Create DCA plans with `createPlan()`
2. ✅ Execute swaps with `executeStep()`
3. ✅ Query plans with `getPlan()` and `getUserPlans()`

Example:
```bash
# Create a DCA plan (swap USDC for ETH every day)
cast send $DIAMOND_ADDRESS \
  "createPlan(address,address,uint256,uint256,uint256)" \
  0xUSDC_ADDRESS 0xWETH_ADDRESS 1000000 86400 30 \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL_BASE
```

Happy building! 🚀
