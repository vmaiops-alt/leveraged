# Architecture

## System Overview

LEVERAGED is built with a modular architecture that separates concerns across multiple smart contracts.

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                           │
│                    (Next.js + wagmi + viem)                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Core Protocol                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  LeveragedVault │  │   LendingPool   │  │  ValueTracker   │  │
│  │                 │◄─┤                 │◄─┤                 │  │
│  │  - Positions    │  │  - Deposits     │  │  - Entry prices │  │
│  │  - Leverage     │  │  - Borrows      │  │  - Exit prices  │  │
│  │  - P&L          │  │  - Interest     │  │  - Fee calc     │  │
│  └────────┬────────┘  └─────────────────┘  └─────────────────┘  │
│           │                                                      │
│  ┌────────▼────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Liquidator    │  │  FeeCollector   │  │   PriceOracle   │  │
│  │                 │  │                 │  │                 │  │
│  │  - Health check │  │  - Collection   │  │  - Chainlink    │  │
│  │  - Batch liq    │  │  - Distribution │  │  - Validation   │  │
│  │  - Keepers      │  │  - Accounting   │  │  - Staleness    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Token Layer                               │
│         ┌─────────────────┐    ┌─────────────────┐              │
│         │    LVGToken     │    │   LVGStaking    │              │
│         │                 │    │                 │              │
│         │  - ERC-20       │    │  - Stake/Unstake│              │
│         │  - Mint/Burn    │    │  - Fee discounts│              │
│         │  - Distribution │    │  - Rewards      │              │
│         └─────────────────┘    └─────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## Contract Relationships

### Data Flow

```
User deposits USDT
       │
       ▼
┌──────────────┐
│LeveragedVault│──────► Borrows from LendingPool
└──────┬───────┘
       │
       ▼
Records entry ──────► ValueTracker
       │
       ▼
Position created
       │
       │ (on close)
       ▼
Calculate P&L ◄────── ValueTracker (entry vs exit)
       │
       ▼
Collect fees ──────► FeeCollector
       │
       ▼
User receives payout
```

### Access Control

| Contract | Owner | Special Roles |
|----------|-------|---------------|
| LeveragedVault | Multisig | - |
| LendingPool | Multisig | Vault (borrow/repay) |
| ValueTracker | Multisig | Vault (record prices) |
| FeeCollector | Multisig | Vault (collect fees) |
| Liquidator | Multisig | Keepers (liquidate) |
| LVGToken | Multisig | Minter (staking contract) |
| LVGStaking | Multisig | - |

## Key Design Decisions

### 1. Synthetic Exposure

We don't actually buy the underlying assets. Instead, we create synthetic exposure through price tracking.

**Benefits:**
- No slippage on large positions
- No DEX integration needed
- Simpler accounting

**Trade-offs:**
- Dependent on oracle accuracy
- No actual asset ownership

### 2. Single Collateral (USDT)

All positions use USDT as collateral.

**Benefits:**
- Simplified liquidations
- Easy P&L calculation
- Stable collateral value

**Trade-offs:**
- USDT dependency risk
- No multi-collateral flexibility

### 3. Isolated Positions

Each position is independent. One position's liquidation doesn't affect others.

**Benefits:**
- Risk isolation
- Flexible management
- Clear accounting

### 4. Keeper-Based Liquidations

External keepers monitor and execute liquidations.

**Benefits:**
- Decentralized operation
- Competitive execution
- Protocol doesn't need to run bots

**Trade-offs:**
- Relies on keeper availability
- MEV considerations

## Upgrade Path

Current contracts are **not upgradeable** for security.

Future versions will be deployed as new contracts with migration paths.

## External Dependencies

| Dependency | Purpose | Risk Mitigation |
|------------|---------|-----------------|
| Chainlink | Price feeds | Staleness checks, fallbacks |
| USDT | Collateral | Widely used, high liquidity |
| BSC | Base layer | Established chain, low fees |
