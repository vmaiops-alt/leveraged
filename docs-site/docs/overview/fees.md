# Fee Structure

## Overview

LEVERAGED uses a unique fee model designed to align incentives with users. You only pay significant fees when you profit.

## Trading Fees

### Entry Fee

| Fee | Rate | When |
|-----|------|------|
| Entry Fee | **0.1%** | When opening a position |

This small fee covers protocol costs and is deducted from your deposit.

**Example:** $1,000 deposit → $1 fee → $999 net deposit

### Value Increase Fee

| Fee | Rate | When |
|-----|------|------|
| Value Fee | **25%** | On profitable close only |

This is our main revenue source. We only charge when you make money.

**Example:**
- Deposit: $1,000
- Close value: $1,400
- Value increase: $400
- Fee (25%): **$100**
- You receive: $1,300

### No Fee on Losses

If your position closes at a loss, you pay **$0** in value fees.

---

## Lending Fees

### Borrow Interest

Traders pay interest on borrowed funds. The rate varies based on utilization:

| Utilization | Borrow APR | Supply APY |
|-------------|------------|------------|
| 0% | 2% | 0% |
| 50% | 5% | 2.5% |
| 80% | 12% | 9.6% |
| 90% | 25% | 22.5% |
| 100% | 100% | 100% |

*APY for lenders = Borrow APR × Utilization*

### Interest Rate Model

We use a kinked interest rate model:

```
If utilization ≤ 80%:
  Rate = 2% + (utilization × 12.5%)

If utilization > 80%:
  Rate = 12% + ((utilization - 80%) × 440%)
```

This incentivizes healthy pool utilization while ensuring lender protection.

---

## Liquidation Fees

### Liquidation Bonus

| Fee | Rate | Recipient |
|-----|------|-----------|
| Liquidation Bonus | **5%** | Liquidator |

When a position is liquidated, the liquidator receives 5% of the position's collateral as incentive.

### Remaining Funds

After debt repayment and liquidator bonus, any remaining funds go to:
1. Insurance fund (for bad debt coverage)
2. Protocol treasury

---

## Staking Fee Discounts

Stake $LVG to reduce your value increase fee:

| LVG Staked | Discount | Effective Fee |
|------------|----------|---------------|
| 0 | 0% | 25.00% |
| 1,000 | 5% | 23.75% |
| 5,000 | 10% | 22.50% |
| 25,000 | 15% | 21.25% |
| 100,000 | 20% | 20.00% |
| 500,000 | 25% | 18.75% |

**Example with 100,000 LVG staked:**
- Value increase: $400
- Base fee (25%): $100
- Discount (20%): -$20
- **Final fee: $80**

---

## Fee Distribution

All collected fees are distributed as follows:

| Recipient | Share | Purpose |
|-----------|-------|---------|
| Treasury | 50% | Protocol development |
| Insurance Fund | 30% | Bad debt coverage |
| LVG Stakers | 20% | Staking rewards |

```
┌─────────────────┐
│  Collected Fees │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌─────────┐ ┌─────────┐
│Treasury│ │Insurance│ │ Stakers │
│  50%   │ │   30%   │ │   20%   │
└───────┘ └─────────┘ └─────────┘
```

---

## Fee Comparison

### vs Perpetual Exchanges

| Fee Type | LEVERAGED | Perpetuals |
|----------|-----------|------------|
| Entry | 0.1% | 0.05-0.1% |
| Exit | 0% | 0.05-0.1% |
| Funding | None | ±0.01% / 8h |
| Profit Fee | 25% | None |

**When LEVERAGED is cheaper:**
- Holding positions for extended periods
- Positions with modest gains
- Any losing position

**When Perpetuals are cheaper:**
- Very large profitable trades
- Quick scalping

### Break-Even Analysis

At what profit % does LEVERAGED become more expensive than a 0.1% trading fee?

```
0.1% + 0.1% = 0.2% total perpetual fees
25% of X = 0.2%
X = 0.8%
```

If your profit exceeds **0.8%**, perpetuals are cheaper on that trade.
But with funding rates factored in over time, LEVERAGED often wins for longer holds.

---

## Gas Fees

All transactions require BSC gas fees (paid in BNB):

| Action | Estimated Gas | Cost @ 5 gwei |
|--------|---------------|---------------|
| Open Position | ~250,000 | ~$0.30 |
| Close Position | ~180,000 | ~$0.22 |
| Add Collateral | ~80,000 | ~$0.10 |
| Stake LVG | ~90,000 | ~$0.11 |
| Claim Rewards | ~70,000 | ~$0.08 |

*BSC gas is typically very cheap ($0.05-0.50 per transaction)*
