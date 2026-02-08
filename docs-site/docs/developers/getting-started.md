---
sidebar_position: 1
---
# Getting Started

Build on LEVERAGED with our smart contracts and APIs.

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/leveraged-finance/leveraged
cd leveraged
```

### 2. Install Dependencies

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install project dependencies
forge install
```

### 3. Build Contracts

```bash
forge build
```

### 4. Run Tests

```bash
forge test
```

### 5. Deploy (Testnet)

```bash
# Set environment variables
export PRIVATE_KEY=your_private_key
export BSC_TESTNET_RPC=https://data-seed-prebsc-1-s1.binance.org:8545

# Deploy
forge script scripts/Deploy.s.sol:DeployTestnet --rpc-url $BSC_TESTNET_RPC --broadcast
```

## Project Structure

```
leveraged/
├── contracts/
│   ├── core/           # Main protocol contracts
│   ├── periphery/      # Supporting contracts
│   ├── strategies/     # Yield strategies
│   ├── token/          # LVG token contracts
│   └── interfaces/     # All interfaces
├── frontend/           # Next.js app
├── subgraph/           # The Graph indexer
├── scripts/            # Deployment scripts
├── test/               # Unit tests
└── docs/               # Documentation
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Contracts | Solidity 0.8.20 |
| Framework | Foundry |
| Frontend | Next.js 14, wagmi, viem |
| Indexer | The Graph |
| Oracles | Chainlink |
| Chain | BNB Smart Chain |

## Development Environment

### Requirements

- Node.js 18+
- Foundry
- Git

### Recommended Tools

- VS Code with Solidity extension
- Tenderly for debugging
- Etherscan for verification

## Network Configuration

### BSC Testnet

| Parameter | Value |
|-----------|-------|
| Chain ID | 97 |
| RPC | `https://data-seed-prebsc-1-s1.binance.org:8545` |
| Explorer | `https://testnet.bscscan.com` |
| Faucet | `https://testnet.bnbchain.org/faucet-smart` |

### BSC Mainnet

| Parameter | Value |
|-----------|-------|
| Chain ID | 56 |
| RPC | `https://bsc-dataseed.binance.org` |
| Explorer | `https://bscscan.com` |

## Next Steps

- [Smart Contracts](contracts.md) - Contract details
- [Integration Guide](integration.md) - Build integrations
- [API Reference](api.md) - Contract functions

## Support

- [Discord](https://discord.gg/leveraged) - Developer channel
- [GitHub Issues](https://github.com/leveraged-finance/leveraged/issues)
