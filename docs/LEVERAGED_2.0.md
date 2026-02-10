# LEVERAGED 2.0 — Feature Documentation

> Major protocol upgrade with Lending V5, Yield Tokenization, Perpetuals, and Governance

**Network:** BSC Mainnet (Chain ID: 56)  
**Release Date:** February 2026  
**Version:** 2.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Contract Addresses](#contract-addresses)
3. [New Features](#new-features)
   - [Lending Pool V5](#1-lending-pool-v5)
   - [Yield Tokenization](#2-yield-tokenization)
   - [Perpetuals](#3-perpetuals)
   - [Governance (veLVG)](#4-governance-velvg)
4. [Architecture](#architecture)
5. [Migration from V1](#migration-from-v1)

---

## Overview

LEVERAGED 2.0 represents a major evolution of the protocol, expanding from leveraged yield farming into a comprehensive DeFi platform. The upgrade introduces four major new systems:

| Feature | Description | Max Leverage |
|---------|-------------|--------------|
| Lending V5 | E-Mode for correlated assets | — |
| Yield Tokenization | PT/YT split (Pendle-style) | — |
| Perpetuals | Leveraged perpetual trading | 50x |
| Governance | veLVG voting + gauges | — |

---

## Contract Addresses

### BSC Mainnet (Chain ID: 56)

| Contract | Address | Purpose |
|----------|---------|---------|
| **LVGToken** | [`0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1`](https://bscscan.com/address/0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1) | Protocol governance token |
| **LVGStaking** | [`0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F`](https://bscscan.com/address/0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F) | Stake LVG for platform rewards |
| **LendingPoolV5** | [`0x088c08057D51B9C76B06102B95EF0555A1c44507`](https://bscscan.com/address/0x088c08057D51B9C76B06102B95EF0555A1c44507) | E-Mode lending with correlated assets |
| **LeveragedFarmV3** | [`0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05`](https://bscscan.com/address/0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05) | Leveraged yield farming (up to 5x) |
| **YieldTokenizer** | [`0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605`](https://bscscan.com/address/0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605) | Principal/Yield token splitting |
| **PerpVault** | [`0x2911013D3c842420fe5189C9166BDdd8aB6E444E`](https://bscscan.com/address/0x2911013D3c842420fe5189C9166BDdd8aB6E444E) | Perpetual trading vault (up to 50x) |
| **PositionManager** | [`0xA93c5D73793F000F200B1c92C796207eE1948f50`](https://bscscan.com/address/0xA93c5D73793F000F200B1c92C796207eE1948f50) | Manages perp positions & liquidations |
| **VotingEscrow** | [`0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D`](https://bscscan.com/address/0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D) | Lock LVG → veLVG |
| **GaugeController** | [`0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5`](https://bscscan.com/address/0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5) | Gauge weight voting |

---

## New Features

### 1. Lending Pool V5

**Contract:** `LendingPoolV5` at `0x088c08057D51B9C76B06102B95EF0555A1c44507`

#### E-Mode (Efficiency Mode)

E-Mode enables higher capital efficiency when supplying and borrowing correlated assets. When assets are price-correlated (e.g., stablecoins, liquid staking derivatives), E-Mode allows:

- **Higher LTV:** Up to 97% for correlated pairs
- **Higher Liquidation Threshold:** Up to 98%
- **Lower Liquidation Penalty:** As low as 1%

#### Supported E-Mode Categories

| Category ID | Name | Assets | Max LTV |
|-------------|------|--------|---------|
| 1 | Stablecoins | USDT, USDC, BUSD, DAI | 97% |
| 2 | BTC Correlated | BTCB, WBTC | 93% |
| 3 | ETH Correlated | ETH, WETH, stETH, rETH | 93% |
| 4 | BNB Correlated | BNB, WBNB, stkBNB | 90% |

#### Key Functions

```solidity
// Enter E-Mode for a specific category
function setUserEMode(uint8 categoryId) external;

// Supply assets to earn interest
function supply(address asset, uint256 amount) external;

// Borrow with E-Mode benefits
function borrow(address asset, uint256 amount) external;

// Get current E-Mode category
function getUserEMode(address user) external view returns (uint8);
```

---

### 2. Yield Tokenization

**Contract:** `YieldTokenizer` at `0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605`

#### PT/YT Split (Pendle-Style)

Yield Tokenization allows users to separate yield-bearing assets into two components:

- **PT (Principal Token):** Represents the principal, redeemable at maturity
- **YT (Yield Token):** Represents the yield stream until maturity

#### Use Cases

| Strategy | Description |
|----------|-------------|
| **Fixed Yield** | Buy PT at discount, redeem at face value at maturity |
| **Yield Speculation** | Buy YT to speculate on variable yields |
| **Yield Hedging** | Sell YT to lock in current rates |
| **LP Provision** | Provide liquidity for PT/YT trading |

#### Supported Underlying Assets

- Lending Pool deposits (lvUSDT, lvBNB, etc.)
- Staking positions (staked LVG)
- Venus supply positions
- PancakeSwap LP tokens

#### Key Functions

```solidity
// Tokenize a yield-bearing asset
function tokenize(
    address underlying,
    uint256 amount,
    uint256 maturity
) external returns (uint256 ptAmount, uint256 ytAmount);

// Redeem PT at maturity for underlying
function redeemPT(address pt, uint256 amount) external;

// Claim accrued yield from YT
function claimYield(address yt) external returns (uint256);

// Merge PT + YT back into underlying (before maturity)
function merge(
    address pt,
    address yt,
    uint256 amount
) external returns (uint256);
```

#### Maturity Periods

- 30 days
- 90 days  
- 180 days
- 365 days

---

### 3. Perpetuals

**Contracts:** 
- `PerpVault` at `0x2911013D3c842420fe5189C9166BDdd8aB6E444E`
- `PositionManager` at `0xA93c5D73793F000F200B1c92C796207eE1948f50`

#### Overview

LEVERAGED 2.0 introduces perpetual futures trading with up to **50x leverage**. The system uses a vault-based architecture where LPs provide liquidity and traders open leveraged positions.

#### Supported Markets

| Market | Max Leverage | Maintenance Margin |
|--------|--------------|-------------------|
| BTC-USD | 50x | 0.5% |
| ETH-USD | 50x | 0.5% |
| BNB-USD | 30x | 1% |
| LVG-USD | 10x | 2.5% |

#### Position Types

- **Long:** Profit when price increases
- **Short:** Profit when price decreases

#### Fee Structure

| Fee Type | Rate |
|----------|------|
| Opening Fee | 0.05% |
| Closing Fee | 0.05% |
| Funding Rate | Variable (±0.01% per 8h) |
| Liquidation Fee | 0.5% |

#### Key Functions

```solidity
// Open a leveraged position
function openPosition(
    bytes32 market,      // e.g., keccak256("BTC-USD")
    bool isLong,
    uint256 collateral,
    uint256 leverage     // 1-50x
) external returns (uint256 positionId);

// Close position
function closePosition(uint256 positionId) external;

// Add collateral to position
function addCollateral(uint256 positionId, uint256 amount) external;

// Liquidate undercollateralized position
function liquidate(uint256 positionId) external;
```

#### Risk Parameters

- **Max Position Size:** $1M per position
- **Max Open Interest:** $50M per market
- **Price Impact:** Progressive (larger positions = more slippage)
- **Funding Interval:** Every 8 hours

---

### 4. Governance (veLVG)

**Contracts:**
- `VotingEscrow` at `0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D`
- `GaugeController` at `0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5`

#### Vote-Escrowed LVG (veLVG)

Users can lock LVG tokens to receive veLVG, which grants:

1. **Voting Power:** Direct protocol governance
2. **Gauge Voting:** Direct emissions to preferred pools
3. **Boosted Rewards:** Up to 2.5x boost on farming rewards
4. **Revenue Share:** Portion of protocol fees

#### Lock Periods & Multipliers

| Lock Period | veLVG per LVG |
|-------------|---------------|
| 1 week | 0.02x |
| 1 month | 0.08x |
| 6 months | 0.5x |
| 1 year | 1x |
| 2 years | 2x |
| 4 years | 4x (max) |

#### Gauge System

Gauges control LVG emission distribution across different pools:

| Gauge | Description |
|-------|-------------|
| Lending Gauges | Rewards for lending pool suppliers |
| Farm Gauges | Rewards for leveraged farmers |
| LP Gauges | Rewards for liquidity providers |
| Perp Gauges | Rewards for perp LPs |

#### Key Functions

```solidity
// Lock LVG for veLVG
function createLock(uint256 amount, uint256 unlockTime) external;

// Increase lock amount
function increaseAmount(uint256 amount) external;

// Extend lock duration
function increaseUnlockTime(uint256 newUnlockTime) external;

// Vote for gauge weights
function voteForGaugeWeights(
    address gauge,
    uint256 weight
) external;

// Withdraw after lock expires
function withdraw() external;
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Frontend (v2)                              │
│                      Next.js 14 + wagmi + viem                       │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────────┐
│                         LEVERAGED 2.0 Contracts                      │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ LendingPool │  │  Leveraged  │  │    Yield    │  │    Perp     │ │
│  │     V5      │  │   FarmV3    │  │  Tokenizer  │  │    Vault    │ │
│  │  (E-Mode)   │  │   (5x)      │  │  (PT/YT)    │  │   (50x)     │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │
│         │                │                │                │        │
│         └────────────────┼────────────────┼────────────────┘        │
│                          │                │                         │
│                   ┌──────▼──────┐  ┌──────▼──────┐                  │
│                   │  Position   │  │   Price     │                  │
│                   │  Manager    │  │   Oracle    │                  │
│                   └─────────────┘  └─────────────┘                  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                      Governance Layer                         │   │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │   │
│  │   │  VotingEscrow │  │    Gauge     │  │   LVGToken   │       │   │
│  │   │   (veLVG)     │  │  Controller  │  │  + Staking   │       │   │
│  │   └──────────────┘  └──────────────┘  └──────────────┘       │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Migration from V1

### For Users

1. **Existing positions are unaffected** — V1 contracts remain operational
2. **New features require V2 contracts** — E-Mode, PT/YT, Perps only on V2
3. **LVG token unchanged** — Same token, new utility (veLVG)

### For Developers

- **New ABIs required** for V2 contracts
- **Subgraph updated** with new event handlers
- **Frontend config** updated with new addresses

### Deprecation Timeline

| Phase | Date | Action |
|-------|------|--------|
| V2 Launch | Feb 2026 | New contracts deployed |
| Migration | Mar 2026 | UI defaults to V2 |
| V1 Sunset | Jun 2026 | V1 contracts read-only |

---

## Resources

- [Main README](../README.md)
- [Security Documentation](SECURITY.md)
- [Security Audit 2.0](SECURITY_AUDIT_2.0.md)
- [Emergency Procedures](EMERGENCY.md)
- [Gas Optimization](GAS_OPTIMIZATION.md)

---

*Last updated: February 2026*
