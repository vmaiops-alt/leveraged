# LEVERAGED

> Leveraged Yield Farming Platform mit bis zu 5x Leverage

## Overview

Leveraged ermöglicht Usern, ihre Yield Farming Positionen mit bis zu 5x Leverage zu verstärken. Die Platform aggregiert die besten Yield-Quellen cross-chain und macht DeFi-Leverage für jeden zugänglich.

## Revenue Model

- **25% Value Increase Fee** — Haupteinnahme auf Asset-Appreciation
- **10% Performance Fee** — Auf erwirtschafteten Yield
- **Borrow Interest Spread** — 2% auf geliehenenes Kapital
- **Liquidation Fee** — 5% bei Liquidationen

## Tech Stack

- **Smart Contracts:** Solidity 0.8.20, Foundry
- **Frontend:** Next.js 14, TailwindCSS, wagmi/viem
- **Backend:** Node.js, The Graph
- **Chains:** BSC (Primary), Arbitrum, Base

## Project Structure

```
leveraged/
├── contracts/
│   ├── core/           # Vault, Lending, ValueTracker
│   ├── strategies/     # Yield Strategies
│   ├── token/          # LVG Token & Staking
│   ├── cross-chain/    # Bridge Contracts
│   ├── periphery/      # Oracle, Liquidator, Fees
│   └── interfaces/     # All Interfaces
├── frontend/           # Next.js App
├── backend/            # API & Indexer
├── scripts/            # Deployment Scripts
├── test/               # Contract Tests
├── deployments/        # Deployed Addresses
└── docs/               # Documentation
```

## Quick Start

```bash
# Install dependencies
forge install

# Run tests
forge test

# Deploy to testnet
forge script scripts/Deploy.s.sol --rpc-url bsc-testnet --broadcast
```

## Contracts

| Contract | Description |
|----------|-------------|
| LeveragedVault | Main vault with leverage logic |
| LendingPool | Internal lending pool for leverage |
| ValueTracker | Tracks entry/exit for 25% fee |
| PriceOracle | Chainlink price feeds |
| Liquidator | Liquidation engine |
| FeeCollector | Fee distribution |
| LVGToken | Governance/utility token |
| LVGStaking | Stake LVG for benefits |

## License

UNLICENSED - Proprietary
