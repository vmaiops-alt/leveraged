---
sidebar_position: 1
---
# Fee Discounts

Stake $LVG to reduce your trading fees.

## Discount Tiers

| Tier | LVG Staked | Discount | Effective Fee |
|------|------------|----------|---------------|
| None | 0 | 0% | 25.00% |
| 🥉 Bronze | 1,000+ | 5% | 23.75% |
| 🥈 Silver | 5,000+ | 10% | 22.50% |
| 🥇 Gold | 25,000+ | 15% | 21.25% |
| 💎 Platinum | 100,000+ | 20% | 20.00% |
| 👑 Diamond | 500,000+ | 25% | 18.75% |

## How It Works

The discount applies to the **25% value increase fee**.

### Example: Gold Tier (15% discount)

```
Position Profit: $1,000
Base Fee (25%): $250
Discount (15%): -$37.50
─────────────────────
Final Fee: $212.50
You Save: $37.50
```

## Savings Calculator

| Profit | No Stake | Bronze | Silver | Gold | Platinum | Diamond |
|--------|----------|--------|--------|------|----------|---------|
| $100 | $25 | $23.75 | $22.50 | $21.25 | $20.00 | $18.75 |
| $500 | $125 | $118.75 | $112.50 | $106.25 | $100.00 | $93.75 |
| $1,000 | $250 | $237.50 | $225.00 | $212.50 | $200.00 | $187.50 |
| $5,000 | $1,250 | $1,187.50 | $1,125.00 | $1,062.50 | $1,000.00 | $937.50 |
| $10,000 | $2,500 | $2,375.00 | $2,250.00 | $2,125.00 | $2,000.00 | $1,875.00 |

## ROI Analysis

How much trading volume to break even on staking?

### Gold Tier (25,000 LVG)

Assuming LVG = $0.10:
- Stake cost: $2,500
- Discount per $1,000 profit: $37.50
- Break-even: ~$67,000 in profits

With additional staking APR (~50%), break-even is much faster.

## Checking Your Tier

### Via App
1. Go to [Stake](https://app.leveraged.finance/stake)
2. See "Your Fee Discount" card

### Via Contract
```solidity
uint256 discount = stakingContract.getFeeDiscount(yourAddress);
// Returns discount in BPS (500 = 5%)
```

## Tier Changes

### Upgrading
Stake more LVG → Tier upgrades immediately.

### Downgrading
Unstake LVG → Tier downgrades immediately.

Discount applies to positions **closed after** tier change, not open positions.

## Combining with Other Benefits

Fee discounts stack with future promotions but have a minimum fee floor of 15%.

## FAQ

**Q: Does the discount apply to entry fees?**
A: No, only to the 25% value increase fee.

**Q: What if I stake after opening a position?**
A: The discount applies when you close, based on your tier at closing time.

**Q: Can I get more than 25% discount?**
A: Currently no. Diamond is the maximum tier.
