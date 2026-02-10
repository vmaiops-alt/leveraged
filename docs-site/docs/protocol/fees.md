---
sidebar_position: 2
---
# Fee Structure

LEVERAGED uses a transparent, performance-based fee model designed to align incentives between the protocol and users.

## Fee Overview

| Fee Type | Rate | When Applied |
|----------|------|--------------|
| Open Fee | 0.1% | When opening a position |
| Close Fee | 0.1% | When closing a position |
| Performance Fee | 10% | On realized profits only |
| Price Appreciation Fee | 25% | On BNB price gains only |
| Liquidation Fee | 1% | When position is liquidated |

## Fee Breakdown

### Open Fee (0.1%)

Charged on your collateral when opening a position.

```
Example:
Deposit: 1 BNB
Open Fee: 0.001 BNB (0.1%)
Position Collateral: 0.999 BNB
```

### Close Fee (0.1%)

Charged on your position value when closing.

```
Example:
Position Value at Close: 1.5 BNB
Close Fee: 0.0015 BNB (0.1%)
```

### Performance Fee (10%)

Applied only to realized profits from yield farming (CAKE rewards, trading fees).

```
Example:
Farming Profit: $100
Performance Fee: $10 (10%)
You Keep: $90
```

**Note:** If your position has no profit, you pay no performance fee.

### Price Appreciation Fee (25%)

Applied only when BNB price increases during your position. This is the core protocol fee.

```
Example:
Entry BNB Price: $600
Exit BNB Price: $700
Price Gain: $100 per BNB
Your Collateral: 1 BNB

Appreciation: $100
Fee (25%): $25
You Keep: $75 of the price gain
```

**Key Points:**
- Only charged on **gains**, never on losses
- Calculated using entry price stored on-chain
- Reduced by up to 50% via LVG staking

### Liquidation Fee (1%)

Charged to positions that get liquidated at 110% health factor threshold.

```
Example:
Position Value at Liquidation: $1,000
Liquidation Fee: $10 (1%)
```

## Fee Reduction via Staking

Stake $LVG tokens to reduce your fees by up to 50%:

| LVG Staked | Fee Reduction | Effective Price Fee |
|------------|---------------|---------------------|
| 0 | 0% | 25.00% |
| 1,000+ | 20% | 20.00% |
| 5,000+ | 30% | 17.50% |
| 10,000+ | 40% | 15.00% |
| 50,000+ | 50% | 12.50% |

### Example with Staking

```
Without Staking:
Price Appreciation: $1,000
Fee (25%): $250

With 50K LVG Staked (50% off):
Price Appreciation: $1,000
Fee (12.5%): $125
You Save: $125
```

## Fee Distribution

All collected fees go to:

| Recipient | Share | Purpose |
|-----------|-------|---------|
| Treasury | 70% | Protocol development, operations |
| Insurance Pool | 20% | Bad debt coverage |
| LVG Stakers | 10% | Staking rewards |

## Comparison with Competitors

| Platform | Entry Fee | Funding Rate | Profit Fee |
|----------|-----------|--------------|------------|
| **LEVERAGED** | 0.1% | None | 25% on gains |
| Alpaca Finance | 0.3% | Variable | 19% |
| Venus | 0.1% | Variable | Interest only |
| PancakeSwap | 0.25% | N/A | N/A |

**Why our model is better:**
- No funding rates eating your position
- Only pay on profits, never on losses
- Predictable fees, no surprises

## Contract Reference

Fees are enforced on-chain in `LeveragedFarmV5`:

```solidity
uint256 public constant OPEN_FEE_BPS = 10;          // 0.1%
uint256 public constant CLOSE_FEE_BPS = 10;         // 0.1%
uint256 public constant PERFORMANCE_FEE_BPS = 1000; // 10%
uint256 public constant APPRECIATION_FEE_BPS = 2500; // 25%
uint256 public constant LIQUIDATION_FEE_BPS = 100;  // 1%
```

## FAQ

**Q: Do I pay fees if I lose money?**
A: No. Performance and appreciation fees only apply to profits.

**Q: Are fees taken from my collateral or profits?**
A: Open/close fees from collateral. Performance/appreciation from profits.

**Q: How do I reduce my fees?**
A: Stake LVG tokens. 50,000+ LVG gives you 50% fee reduction.

**Q: What's the minimum fee I can pay?**
A: With max staking: 0.1% open + 0.1% close + 12.5% price appreciation.
