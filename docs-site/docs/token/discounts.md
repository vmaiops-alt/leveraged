---
sidebar_position: 3
---
# Fee Discounts

Stake $LVG to reduce your trading fees by up to 50%.

## Staking Tiers

| Tier | LVG Staked | Fee Reduction | Price Fee | Performance Fee |
|------|------------|---------------|-----------|-----------------|
| None | 0 | 0% | 25.00% | 10.00% |
| 🥉 Bronze | 1,000+ | 20% | 20.00% | 8.00% |
| 🥈 Silver | 5,000+ | 30% | 17.50% | 7.00% |
| 🥇 Gold | 10,000+ | 40% | 15.00% | 6.00% |
| 💎 Diamond | 50,000+ | 50% | 12.50% | 5.00% |

## How It Works

The discount applies to **all percentage-based fees**:
- Price Appreciation Fee (25% base)
- Performance Fee (10% base)

Fixed fees (0.1% open/close) are not reduced.

### Example: Gold Tier (40% reduction)

```
Position closes with:
- BNB Price Gain: $1,000
- Farming Profit: $200

Without Staking:
├─ Price Fee (25%): $250
├─ Performance Fee (10%): $20
└─ Total Fees: $270

With 10K LVG (40% off):
├─ Price Fee (15%): $150
├─ Performance Fee (6%): $12
└─ Total Fees: $162

You Save: $108 (40%)
```

## Savings Calculator

### On $1,000 Price Appreciation

| Tier | Base Fee | Discounted | You Save |
|------|----------|------------|----------|
| None | $250 | $250 | $0 |
| Bronze | $250 | $200 | $50 |
| Silver | $250 | $175 | $75 |
| Gold | $250 | $150 | $100 |
| Diamond | $250 | $125 | $125 |

### Annual Savings (Active Trader)

Assuming $10,000/month in gains:

| Tier | Annual Fees | With Staking | Saved |
|------|-------------|--------------|-------|
| None | $30,000 | $30,000 | $0 |
| Bronze | $30,000 | $24,000 | $6,000 |
| Silver | $30,000 | $21,000 | $9,000 |
| Gold | $30,000 | $18,000 | $12,000 |
| Diamond | $30,000 | $15,000 | $15,000 |

## ROI Analysis

### Gold Tier (10,000 LVG)

Assuming LVG = $0.10:
- Stake cost: $1,000
- Savings per $1,000 gain: $100
- Break-even: $10,000 in gains
- Plus: ~50% staking APR

### Diamond Tier (50,000 LVG)

Assuming LVG = $0.10:
- Stake cost: $5,000
- Savings per $1,000 gain: $125
- Break-even: $40,000 in gains
- Plus: ~50% staking APR

## How to Stake

1. Go to [Stake](https://frontend-vite-gilt.vercel.app) → Stake tab
2. Approve LVG tokens
3. Enter amount to stake
4. Confirm transaction
5. Discount applies immediately

## Checking Your Tier

### Via Contract

```solidity
// Get discount percentage (in basis points)
uint256 discount = stakingContract.getFeeDiscount(yourAddress);
// 2000 = 20%, 3000 = 30%, etc.
```

### Discount Calculation

```solidity
function getFeeDiscount(address user) public view returns (uint256) {
    uint256 staked = stakedAmount[user];
    
    if (staked >= 50_000e18) return 5000; // 50%
    if (staked >= 10_000e18) return 4000; // 40%
    if (staked >= 5_000e18) return 3000;  // 30%
    if (staked >= 1_000e18) return 2000;  // 20%
    return 0;
}
```

## Tier Changes

### Upgrading
Stake more LVG → Tier upgrades immediately.

### Downgrading
Unstake LVG → Tier downgrades immediately.

**Important:** Discount applies based on your tier when **closing** the position, not when opening.

## Combining Benefits

- ✅ Fee discounts apply to all positions
- ✅ Staking APR earned simultaneously
- ✅ Future governance rights
- ✅ Protocol revenue share (coming soon)

## FAQ

**Q: Does staking lock my tokens?**
A: No lock period. Unstake anytime (instant).

**Q: What if I stake after opening a position?**
A: Discount applies when you close, based on tier at closing time.

**Q: Can I get more than 50% discount?**
A: No, Diamond (50K LVG) is the maximum tier.

**Q: Do open/close fees get discounted?**
A: No, only percentage-based profit fees are reduced.
