# 🚀 Deploying to Base Mainnet

This guide walks you through deploying the Principal Protected Vault to Base mainnet.

## 📋 Prerequisites

1. **Foundry installed** - [Install Guide](https://book.getfoundry.sh/getting-started/installation)
2. **Base ETH** - ~0.01 ETH (~$30) for deployment gas
3. **Private Key** - Wallet with ETH on Base
4. **BaseScan API Key** (optional, for verification)

---

## 💰 Step 1: Get Base ETH

### Option A: Bridge from Ethereum
1. Go to [bridge.base.org](https://bridge.base.org)
2. Connect wallet
3. Bridge 0.01 ETH from Ethereum → Base
4. Wait ~5 minutes

### Option B: Buy on Exchange
1. Buy ETH on Coinbase
2. Withdraw to Base network
3. Send to your deployment wallet

---

## 🔐 Step 2: Set Environment Variables

```bash
# Export your private key (⚠️ NEVER commit this!)
export PRIVATE_KEY="0x..."

# Optional: BaseScan API key for verification
export BASESCAN_API_KEY="your_key_here"
```

---

## 🚀 Step 3: Deploy

```bash
# Deploy to Base mainnet
forge script script/DeployPPV.s.sol \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY

# If verification fails, verify manually later:
forge verify-contract \
  <DIAMOND_ADDRESS> \
  src/Diamond.sol:Diamond \
  --chain-id 8453 \
  --etherscan-api-key $BASESCAN_API_KEY
```

---

## 📊 Step 4: Post-Deployment

### A. Save Contract Addresses

The script will output addresses like:

```
Diamond:            0x...
PPVFacet:           0x...
DiamondCutFacet:    0x...
DiamondLoupeFacet:  0x...
OwnershipFacet:     0x...
```

**Save these to `deployments/base-mainnet.json`:**

```json
{
  "network": "Base Mainnet",
  "chainId": 8453,
  "timestamp": "2024-12-05T13:40:00Z",
  "deployer": "0x...",
  "contracts": {
    "diamond": "0x...",
    "ppvFacet": "0x...",
    "diamondCutFacet": "0x...",
    "diamondLoupeFacet": "0x...",
    "ownershipFacet": "0x..."
  },
  "config": {
    "depositToken": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "insuranceFeeBps": 200
  }
}
```

### B. Fund the Reserve

```bash
# Get some USDC on Base
# Then fund the reserve (e.g., 500 USDC)

cast send <DIAMOND_ADDRESS> \
  "fundReserve(uint256)" \
  500000000 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

### C. Test a Deposit

```bash
# 1. Approve USDC
cast send 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "approve(address,uint256)" \
  <DIAMOND_ADDRESS> \
  1000000000 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY

# 2. Deposit 1000 USDC
cast send <DIAMOND_ADDRESS> \
  "deposit(uint256)" \
  1000000000 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

---

## 🔍 Step 5: Verify on BaseScan

1. Go to `https://basescan.org/address/<DIAMOND_ADDRESS>`
2. Check **Contract** tab - should show "✅ Verified"
3. Check **Read Contract** - should show all PPV functions
4. Check **Write Contract** - connect wallet and test

---

## 📝 Step 6: Update README

Add deployment info to your README:

```markdown
## 🌐 Live Deployment

**Network:** Base Mainnet  
**Diamond Contract:** [`0x...`](https://basescan.org/address/0x...)  
**PPVFacet:** [`0x...`](https://basescan.org/address/0x...)

### Try It Out

1. Get USDC on Base
2. Approve Diamond: `0x...`
3. Call `deposit(amount)` 
4. Wait for yield
5. Call `withdraw()` - get your principal back guaranteed! 🛡️
```

---

## ⚠️ Troubleshooting

### "Insufficient funds for gas"
- You need more ETH on Base. Bridge at least 0.01 ETH.

### "Nonce too low"
```bash
# Reset nonce
cast nonce <YOUR_ADDRESS> --rpc-url https://mainnet.base.org
```

### Verification Failed
```bash
# Manually verify
forge verify-contract \
  <CONTRACT_ADDRESS> \
  <CONTRACT_PATH>:<CONTRACT_NAME> \
  --chain-id 8453 \
  --etherscan-api-key $BASESCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,tuple[])" <ARGS>)
```

---

## 📊 Gas Costs (Estimate)

| Action | Gas | Cost (at 0.1 gwei) |
|--------|-----|-------------------|
| Deploy Diamond | ~2.5M | ~0.0025 ETH |
| Deploy Facets | ~3M total | ~0.003 ETH |
| Configuration | ~100k | ~0.0001 ETH |
| **Total** | **~5.6M** | **~0.006 ETH (~$18)** |

---

## ✅ Checklist

- [ ] Got 0.01 ETH on Base
- [ ] Set `PRIVATE_KEY` env var
- [ ] Ran deployment script
- [ ] Saved contract addresses
- [ ] Verified on BaseScan
- [ ] Funded reserve with USDC
- [ ] Tested deposit/withdraw
- [ ] Updated README with links
- [ ] Added to hackathon submission

---

## 🎉 Success!

Your Principal Protected Vault is now live on Base mainnet!

**Next:** Add the BaseScan links to your hackathon submission so judges can:
- ✅ View verified source code
- ✅ See real Aave V3 integration
- ✅ Test deposits/withdrawals
- ✅ Verify principal protection works
