# LEVERAGED 2.0

> Advanced DeFi Platform: Leveraged Yield Farming, Yield Tokenization & Perpetuals

[![License](https://img.shields.io/badge/license-UNLICENSED-red.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![BSC](https://img.shields.io/badge/chain-BSC-yellow.svg)](https://www.bnbchain.org/)

## Overview

LEVERAGED enables users to amplify their crypto exposure with up to 5x leverage. The platform features a revolutionary fee model where users only pay 25% of their value increase — not their principal or yield.

### Key Features

- 🚀 **Up to 5x Leverage** on BTC, ETH, BNB (Farming)
- 📈 **Up to 50x Leverage** on Perpetuals
- 💰 **25% Value Fee** — Only pay on profits
- 🏦 **Lending Pool V5** — E-Mode for correlated assets
- 🔀 **Yield Tokenization** — PT/YT split (Pendle-style)
- 🪙 **$LVG Token** — veLVG voting + gauge system
- 🗳️ **Governance** — Vote-escrowed LVG for protocol decisions
- 🔒 **Liquidation Protection** — Health factor monitoring
- ⚡ **BSC Optimized** — Low fees, fast transactions

### What's New in 2.0

See [LEVERAGED_2.0.md](docs/LEVERAGED_2.0.md) for full details on the V2 upgrade.

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

### BSC Mainnet (Chain ID: 56) — LEVERAGED 2.0

| Contract | Address | Description |
|----------|---------|-------------|
| LVGToken | [`0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1`](https://bscscan.com/address/0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1) | Governance token |
| LVGStaking | [`0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F`](https://bscscan.com/address/0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F) | Stake LVG for rewards |
| LendingPoolV5 | [`0x088c08057D51B9C76B06102B95EF0555A1c44507`](https://bscscan.com/address/0x088c08057D51B9C76B06102B95EF0555A1c44507) | E-Mode lending |
| LeveragedFarmV3 | [`0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05`](https://bscscan.com/address/0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05) | Leveraged yield farming |
| YieldTokenizer | [`0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605`](https://bscscan.com/address/0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605) | PT/YT tokenization |
| PerpVault | [`0x2911013D3c842420fe5189C9166BDdd8aB6E444E`](https://bscscan.com/address/0x2911013D3c842420fe5189C9166BDdd8aB6E444E) | Perpetuals vault |
| PositionManager | [`0xA93c5D73793F000F200B1c92C796207eE1948f50`](https://bscscan.com/address/0xA93c5D73793F000F200B1c92C796207eE1948f50) | Position management |
| VotingEscrow | [`0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D`](https://bscscan.com/address/0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D) | veLVG locking |
| GaugeController | [`0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5`](https://bscscan.com/address/0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5) | Gauge voting |

### BSC Testnet (Chain ID: 97)

| Contract | Address |
|----------|---------|
| LeveragedVault | `TBD` |
| LendingPool | `TBD` |
| LVGToken | `TBD` |

## Documentation

- [LEVERAGED 2.0 Features](docs/LEVERAGED_2.0.md) ⭐ **NEW**
- [Security Documentation](docs/SECURITY.md)
- [Security Audit 2.0](docs/SECURITY_AUDIT_2.0.md)
- [Emergency Procedures](docs/EMERGENCY.md)
- [Gas Optimization](docs/GAS_OPTIMIZATION.md)
- [Cross-Chain Research](docs/CROSS_CHAIN_RESEARCH.md)
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
| V2 Contracts | ✅ Complete | 100% |
| Audit | ✅ Complete | 100% |
| Mainnet Deploy | ✅ Complete | 100% |

**LEVERAGED 2.0 — Live on BSC Mainnet 🚀**

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
