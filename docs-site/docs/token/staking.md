---
sidebar_position: 1
---
# Staking

Stake your $LVG tokens to earn rewards and unlock fee discounts.

## Benefits

| Benefit | Description |
|---------|-------------|
| 💰 Revenue Share | Earn 20% of protocol fees |
| 🎁 Fee Discounts | Reduce trading fees up to 25% |
| 🗳️ Governance | Vote on proposals (coming soon) |

## How to Stake

### Step 1: Get LVG
- Buy on PancakeSwap
- Earn from farming
- Receive from airdrop

### Step 2: Approve
If first time, approve the staking contract to spend your LVG.

### Step 3: Stake
1. Go to [Stake](https://app.leveraged.finance/stake)
2. Enter amount
3. Click "Stake"
4. Confirm transaction

### Step 4: Earn
Your rewards start accruing immediately!

## Reward Distribution

### Source of Rewards
20% of all protocol fees go to stakers:

```
Protocol Fees → FeeCollector
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
    Treasury    Insurance    Stakers
      50%         30%         20%
```

### How Rewards Work

1. Fees accumulate in FeeCollector
2. Distribution is triggered (manual or automatic)
3. Rewards sent to staking contract
4. Proportionally distributed to stakers

### Claiming Rewards

Rewards are paid in **USDT**:
1. Go to Stake page
2. See "Pending Rewards"
3. Click "Claim"
4. USDT sent to your wallet

## Staking Tiers

Your staked amount determines your fee discount:

| Tier | LVG Required | Fee Discount | Effective Fee |
|------|--------------|--------------|---------------|
| Bronze | 1,000 | 5% | 23.75% |
| Silver | 5,000 | 10% | 22.50% |
| Gold | 25,000 | 15% | 21.25% |
| Platinum | 100,000 | 20% | 20.00% |
| Diamond | 500,000 | 25% | 18.75% |

### Tier Benefits

Higher tiers unlock:
- ✅ Larger fee discounts
- ✅ Priority support (future)
- ✅ Exclusive features (future)
- ✅ Governance weight (future)

## Unstaking

### No Lock Period
Unstake anytime without penalties.

### Process
1. Go to Stake page
2. Switch to "Unstake" tab
3. Enter amount
4. Click "Unstake"
5. LVG returned to wallet

### Considerations
- Unstaking reduces your fee discount tier
- Unclaimed rewards can still be claimed after unstaking
- No cooldown period

## APR Calculation

Staking APR depends on:
1. Total fees generated
2. Total LVG staked
3. LVG price

```
APR = (Annual Fees × 20%) / (Total Staked × LVG Price) × 100%
```

### Example
```
Annual Protocol Fees: $10,000,000
Staker Share (20%): $2,000,000
Total LVG Staked: 20,000,000
LVG Price: $0.10
Staked Value: $2,000,000

APR = $2,000,000 / $2,000,000 × 100% = 100% APR
```

## Smart Contract

### Key Functions

```solidity
// Stake LVG tokens
function stake(uint256 amount) external;

// Unstake LVG tokens
function unstake(uint256 amount) external;

// Claim USDT rewards
function claimRewards() external returns (uint256);

// View functions
function getStakedAmount(address user) external view returns (uint256);
function getPendingRewards(address user) external view returns (uint256);
function getFeeDiscount(address user) external view returns (uint256);
function totalStaked() external view returns (uint256);
```

### Events

```solidity
event Staked(address indexed user, uint256 amount);
event Unstaked(address indexed user, uint256 amount);
event RewardsClaimed(address indexed user, uint256 amount);
```

## FAQ

**Q: When do I start earning rewards?**
A: Immediately after staking.

**Q: How often can I claim?**
A: Anytime. There's no minimum.

**Q: Is there a maximum stake?**
A: No maximum limit.

**Q: Can I stake from multiple wallets?**
A: Yes, but fee discounts are per-wallet.

**Q: What if I unstake partially?**
A: Your tier is recalculated based on remaining stake.
