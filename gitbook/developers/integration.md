# Integration Guide

Build applications and integrations with LEVERAGED.

## JavaScript/TypeScript

### Using wagmi/viem

```typescript
import { useReadContract, useWriteContract } from 'wagmi';
import { parseUnits } from 'viem';

// Read position data
const { data: position } = useReadContract({
  address: VAULT_ADDRESS,
  abi: VAULT_ABI,
  functionName: 'getPosition',
  args: [positionId],
});

// Open position
const { writeContract } = useWriteContract();

const openPosition = async () => {
  writeContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'openPosition',
    args: [
      assetAddress,
      parseUnits('1000', 18), // 1000 USDT
      30000n, // 3x leverage
    ],
  });
};
```

### Using ethers.js

```typescript
import { ethers } from 'ethers';

const vault = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, signer);

// Open position
const tx = await vault.openPosition(
  assetAddress,
  ethers.parseUnits('1000', 18),
  30000 // 3x
);
await tx.wait();

// Read position
const position = await vault.getPosition(positionId);
```

## Python

```python
from web3 import Web3

w3 = Web3(Web3.HTTPProvider('https://bsc-dataseed.binance.org'))
vault = w3.eth.contract(address=VAULT_ADDRESS, abi=VAULT_ABI)

# Read position
position = vault.functions.getPosition(position_id).call()

# Open position
tx = vault.functions.openPosition(
    asset_address,
    w3.to_wei(1000, 'ether'),
    30000  # 3x
).build_transaction({
    'from': account.address,
    'nonce': w3.eth.get_transaction_count(account.address),
})
signed = account.sign_transaction(tx)
tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
```

## Common Operations

### Check User Positions

```typescript
const positionIds = await vault.getUserPositions(userAddress);
const positions = await Promise.all(
  positionIds.map(id => vault.getPosition(id))
);
```

### Calculate P&L

```typescript
const [pnl, pnlPercent] = await vault.getPositionPnL(positionId);
// pnl is in USDT (int256, can be negative)
// pnlPercent is in BPS (int256)
```

### Monitor Health Factor

```typescript
const healthFactor = await vault.getHealthFactor(positionId);
// Returns BPS (10000 = 1.0)
if (healthFactor < 11000n) {
  console.warn('Position at risk of liquidation');
}
```

## Webhooks & Events

Subscribe to events for real-time updates:

```typescript
vault.on('PositionOpened', (positionId, user, asset, deposit, leverage, price) => {
  console.log(`New position: ${positionId} by ${user}`);
});

vault.on('PositionClosed', (positionId, user, exitPrice, valueIncrease, fee, payout) => {
  console.log(`Position closed: ${positionId}, payout: ${payout}`);
});
```

## Testing

### Local Fork

```bash
# Fork BSC mainnet
anvil --fork-url https://bsc-dataseed.binance.org

# Deploy and test
forge script scripts/Deploy.s.sol --rpc-url http://localhost:8545
```

### Testnet

Use BSC Testnet for integration testing:
- Get test BNB from faucet
- Use testnet USDT
- Contracts deployed at testnet addresses

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| Public RPC | 10 req/s |
| Subgraph | 1000 req/day (free) |
| Custom RPC | Unlimited |

## Support

Need help? Reach out:
- Discord: #developers channel
- GitHub: Open an issue
