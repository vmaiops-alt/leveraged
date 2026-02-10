---
slug: /
sidebar_position: 1
title: Introduction
---

# LEVERAGED

> Leveraged Yield Farming on PancakeSwap with up to 3x Leverage

## What is LEVERAGED?

**LEVERAGED** is a decentralized leveraged yield farming platform built on BNB Smart Chain (BSC). It enables users to amplify their PancakeSwap farming returns with up to **3x leverage** while earning CAKE rewards and trading fees.

Deposit BNB, borrow USDT from our lending pool, and farm LP tokens with amplified exposure. Our smart contracts handle all the complexity – swapping, LP creation, and staking on MasterChef V2.

## Why LEVERAGED?

### 🌾 Amplified Farming

Turn 1 BNB into 3 BNB worth of farming exposure. Earn more CAKE rewards and trading fees without selling your BNB.

### 💰 Fair Fee Model

- **0.1%** open fee
- **0.1%** close fee
- **10%** on farming profits
- **25%** on BNB price gains (only when profitable)

No funding rates. No fees on losses.

### 🏦 Passive Lending

Don't want leverage? Deposit USDT into our lending pool and earn **~10-50% APY** from borrowers.

### 🪙 LVG Benefits

Stake $LVG to reduce fees by up to **50%** and earn protocol revenue.

## Supported Pools

| Pool | Assets | Max Leverage | Base APY |
|------|--------|--------------|----------|
| USDT-BNB | USDT/WBNB | 3x | ~9% |
| CAKE-BNB | CAKE/WBNB | 3x | ~20% |
| ETH-BNB | ETH/WBNB | 3x | ~7% |
| BTCB-BNB | BTCB/WBNB | 3x | ~5% |

*APYs from PancakeSwap V2 MasterChef*

## Fee Structure

| Fee | Rate | When |
|-----|------|------|
| Open | 0.1% | Opening position |
| Close | 0.1% | Closing position |
| Performance | 10% | On farming profits |
| Price Appreciation | 25% | On BNB price gains |
| Liquidation | 1% | If liquidated |

**Stake LVG to reduce fees:**

| Staked | Discount |
|--------|----------|
| 1,000 LVG | 20% off |
| 5,000 LVG | 30% off |
| 10,000 LVG | 40% off |
| 50,000 LVG | 50% off |

## Key Metrics

| Metric | Value |
|--------|-------|
| Chain | BNB Smart Chain (56) |
| Max Leverage | 3x |
| Liquidation Threshold | 110% Health Factor |
| Insurance Pool | 1% of interest |
| Liquidation Bonus | 5% |

## Smart Contracts

| Contract | Address |
|----------|---------|
| LeveragedFarmV5 | `0xdcfFA96A8440C9d027C530FCA5b93e695f6c0574` |
| LendingPoolV4 | `0xC57fecAa960Cb9CA70f8C558153314ed17b64c02` |
| LVGToken | `0x17D2b7C19578478a867b68eAdcE61f0c546f00Ea` |
| LVGStaking | `0xE6f9eDA0344e0092a6c6Bb8f6D29112646821cf2` |

## Quick Links

- 🚀 **[Launch App](https://frontend-vite-gilt.vercel.app)** – Start farming
- 📖 **[How It Works](/overview/how-it-works)** – Learn the basics
- 💸 **[Fee Structure](/protocol/fees)** – Understand costs
- 💎 **[$LVG Token](/token/tokenomics)** – Staking and discounts
- 🔒 **[Security](/security/risks)** – Risks and audits

## How It Works

```
┌─────────────┐     Deposit BNB      ┌──────────────┐
│    User     │ ──────────────────▶  │  Leveraged   │
│             │                      │    Farm      │
└─────────────┘                      └──────┬───────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    │                       │                       │
                    ▼                       ▼                       ▼
            ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
            │   Lending    │       │  PancakeSwap │       │   MasterChef │
            │    Pool      │       │   Router     │       │      V2      │
            │  (Borrow)    │       │   (Swap)     │       │   (Stake)    │
            └──────────────┘       └──────────────┘       └──────────────┘
```

1. **Deposit** – User deposits BNB with chosen leverage
2. **Borrow** – Contract borrows USDT for leverage
3. **Swap** – BNB swapped to LP tokens via PancakeSwap
4. **Stake** – LP tokens staked in MasterChef V2
5. **Earn** – CAKE rewards + trading fees accumulate
6. **Close** – Unstake, swap back, repay loan, return profit

---

:::warning Risk Warning
Leveraged farming involves significant risk. Positions can be liquidated if health factor drops below 110%. Only farm with funds you can afford to lose. This is not financial advice.
:::
