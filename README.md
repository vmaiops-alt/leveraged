# LEVERAGED

> Leveraged Yield Farming Platform with up to 5x Leverage

[![License](https://img.shields.io/badge/license-UNLICENSED-red.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![BSC](https://img.shields.io/badge/chain-BSC-yellow.svg)](https://www.bnbchain.org/)

## Overview

LEVERAGED enables users to amplify their crypto exposure with up to 5x leverage. The platform features a revolutionary fee model where users only pay 25% of their value increase — not their principal or yield.

### Key Features

- 🚀 **Up to 5x Leverage** on BTC, ETH, BNB
- 💰 **25% Value Fee** — Only pay on profits
- 🏦 **Lending Pool** — Earn yield by providing liquidity
- 🪙 **$LVG Token** — Stake for fee discounts + revenue share
- 🔒 **Liquidation Protection** — Health factor monitoring
- ⚡ **BSC Optimized** — Low fees, fast transactions

## Revenue Model

| Fee Type | Rate | Description |
|----------|------|-------------|
| Value Increase Fee | 25% | Main revenue on asset appreciation |
| Performance Fee | 10% | On yield earned |
| Entry Fee | 0.1% | On position opening |
| Borrow Interest | Variable | Spread on borrowed capital |
| Liquidation Bonus | 5% | For liquidators |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Frontend                             │
│                    (Next.js + wagmi)                         │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                      Core Contracts                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Leveraged  │  │   Lending    │  │    Value     │       │
│  │    Vault     │◄─┤    Pool      │◄─┤   Tracker    │       │
│  └──────┬───────┘  └──────────────┘  └──────────────┘       │
│         │                                                    │
│  ┌──────▼───────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Liquidator  │  │     Fee      │  │    Price     │       │
│  │              │  │  Collector   │  │   Oracle     │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                       Token Layer                            │
│         ┌──────────────┐    ┌──────────────┐                │
│         │  LVG Token   │    │ LVG Staking  │                │
│         └──────────────┘    └──────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
leveraged/
├── contracts/
│   ├── core/              # Core protocol contracts
│   │   ├── LeveragedVault.sol
│   │   ├── LendingPool.sol
│   │   ├── ValueTracker.sol
│   │   ├── FeeCollector.sol
│   │   └── StrategyManager.sol
│   ├── periphery/         # Supporting contracts
│   │   ├── PriceOracle.sol
│   │   └── Liquidator.sol
│   ├── strategies/        # Yield strategies
│   │   ├── BaseStrategy.sol
│   │   ├── PancakeSwapStrategy.sol
│   │   └── VenusStrategy.sol
│   ├── token/             # Token contracts
│   │   ├── LVGToken.sol
│   │   └── LVGStaking.sol
│   └── interfaces/        # All interfaces
├── frontend/              # Next.js 14 app
│   ├── src/
│   │   ├── app/           # Pages (dashboard, trade, earn, stake)
│   │   ├── components/    # React components
│   │   ├── hooks/         # Contract hooks
│   │   └── config/        # ABIs, addresses
│   └── README.md
├── scripts/               # Foundry deployment scripts
├── test/                  # Unit tests
├── subgraph/              # The Graph indexer
├── docs/                  # Documentation
│   ├── SECURITY.md
│   ├── EMERGENCY.md
│   └── GAS_OPTIMIZATION.md
└── deployments/           # Deployed addresses
```

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- Node.js 18+
- npm or yarn

### Smart Contracts

```bash
# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run tests with gas report
forge test --gas-report

# Deploy to BSC Testnet
forge script scripts/Deploy.s.sol:DeployTestnet \
  --rpc-url $BSC_TESTNET_RPC \
  --broadcast \
  --verify
```

### Frontend

```bash
cd frontend

# Install dependencies
npm install

# Create .env.local
echo "NEXT_PUBLIC_WC_PROJECT_ID=your_walletconnect_id" > .env.local

# Run development server
npm run dev

# Build for production
npm run build
```

### Subgraph

```bash
cd subgraph

# Install Graph CLI
npm install -g @graphprotocol/graph-cli

# Generate types
graph codegen

# Build
graph build

# Deploy (update subgraph.yaml with deployed addresses first)
graph deploy --studio leveraged
```

## Contract Addresses

### BSC Testnet (Chain ID: 97)

| Contract | Address |
|----------|---------|
| LeveragedVault | `TBD` |
| LendingPool | `TBD` |
| FeeCollector | `TBD` |
| Liquidator | `TBD` |
| LVGToken | `TBD` |
| LVGStaking | `TBD` |
| PriceOracle | `TBD` |

### BSC Mainnet (Chain ID: 56)

| Contract | Address |
|----------|---------|
| ... | Coming after audit |

## Documentation

- [Security Documentation](docs/SECURITY.md)
- [Emergency Procedures](docs/EMERGENCY.md)
- [Gas Optimization](docs/GAS_OPTIMIZATION.md)
- [Frontend README](frontend/README.md)

## Security

⚠️ **This code is unaudited. Use at your own risk.**

For security concerns, see [SECURITY.md](docs/SECURITY.md).

## Development Status

| Phase | Status | Progress |
|-------|--------|----------|
| Core Contracts | ✅ Complete | 100% |
| Yield Strategies | ✅ Complete | 100% |
| LVG Token | ✅ Complete | 100% |
| Unit Tests | ✅ Complete | 100% |
| Deployment Scripts | ✅ Complete | 100% |
| Frontend | ✅ Complete | 100% |
| Subgraph | ✅ Complete | 100% |
| Documentation | ✅ Complete | 100% |
| Audit | 🔲 Pending | 0% |
| Mainnet Deploy | 🔲 Pending | 0% |

**Overall: ~85% Complete**

## Tech Stack

- **Smart Contracts:** Solidity 0.8.20, Foundry
- **Frontend:** Next.js 14, React 18, Tailwind CSS
- **Wallet:** wagmi v2, RainbowKit v2, viem
- **Indexer:** The Graph (AssemblyScript)
- **Oracles:** Chainlink Price Feeds
- **Chain:** BNB Smart Chain (BSC)

## Contributing

This is a private repository. Contact the team for contribution guidelines.

## License

UNLICENSED - All rights reserved.

---

Built with 🔧 by the LEVERAGED team
