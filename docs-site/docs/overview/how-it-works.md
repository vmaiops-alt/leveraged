# How It Works

## Opening a Position

### Step 1: Connect Wallet

Connect your Web3 wallet (MetaMask, Trust Wallet, etc.) to the LEVERAGED app. Make sure you're on BNB Smart Chain.

### Step 2: Deposit Collateral

Deposit USDT as collateral. This will be used to open your leveraged position.

:::info
You'll need to approve USDT spending first if it's your first time.
:::

### Step 3: Choose Your Asset

Select which asset you want exposure to:
- **BTC** - Bitcoin
- **ETH** - Ethereum  
- **BNB** - BNB

### Step 4: Set Your Leverage

Choose your leverage multiplier from 1x to 5x:

| Leverage | Risk Level | Liquidation Buffer |
|----------|------------|-------------------|
| 1x | Low | No liquidation risk |
| 2x | Medium | ~42% price drop |
| 3x | Medium-High | ~28% price drop |
| 4x | High | ~21% price drop |
| 5x | Very High | ~17% price drop |

### Step 5: Review & Confirm

Review your position details:
- Entry fee (0.1%)
- Total exposure
- Estimated liquidation price
- Health factor

Click "Open Position" and confirm the transaction.

---

## Position Mechanics

### How Leverage Works

When you open a leveraged position, the protocol:

1. **Takes your deposit** (e.g., $1,000 USDT)
2. **Deducts entry fee** (0.1% = $1)
3. **Borrows additional funds** from the lending pool
4. **Creates synthetic exposure** to your chosen asset

```
Your Deposit: $1,000
Leverage: 3x
─────────────────────
Total Exposure: $3,000
Your Capital: $999 (after fee)
Borrowed: $2,001
```

### Price Tracking

Your position's value changes based on the asset's price:

```
Entry Price: $50,000 (BTC)
Current Price: $55,000 (+10%)
Your Leverage: 3x
─────────────────────
Position Change: +30%
```

### Health Factor

The health factor measures your position's safety:

```
Health Factor = Position Value / Debt

> 1.5  → 🟢 Safe
1.1-1.5 → 🟡 Warning
< 1.1  → 🔴 Liquidatable
```

---

## Closing a Position

### Profitable Position

When your position is in profit:

1. Click "Close Position"
2. Protocol calculates value increase
3. **25% fee** on value increase is deducted
4. Remaining profit + deposit returned to you

**Example:**
```
Deposit: $1,000
Position Value at Close: $1,300
Value Increase: $300
Platform Fee (25%): $75
─────────────────────
You Receive: $1,225
Net Profit: $225 (22.5%)
```

### Loss Position

When your position is at a loss:

1. Click "Close Position"
2. No platform fee charged
3. Remaining value returned to you

**Example:**
```
Deposit: $1,000
Position Value at Close: $800
Value Decrease: -$200
Platform Fee: $0
─────────────────────
You Receive: $800
Net Loss: -$200 (-20%)
```

---

## Liquidation

### When Does Liquidation Happen?

A position gets liquidated when its health factor drops below **1.1** (110%).

This typically happens when:
- Asset price drops significantly
- Accrued interest increases debt
- You're using high leverage

### Liquidation Process

1. Keeper bots monitor all positions
2. Unhealthy positions are flagged
3. Liquidator repays debt
4. Liquidator receives 5% bonus
5. Remaining funds go to insurance fund

### Avoiding Liquidation

- ✅ Use lower leverage
- ✅ Monitor your health factor
- ✅ Add collateral when needed
- ✅ Set price alerts

---

## Lending

### Depositing

1. Go to "Earn" page
2. Enter USDT amount
3. Click "Deposit"
4. Receive lvUSDT (receipt token)

### Earning Interest

Interest accrues automatically based on:
- Pool utilization rate
- Interest rate model

Higher utilization = Higher APY for lenders

### Withdrawing

1. Go to "Earn" page
2. Enter withdrawal amount
3. Click "Withdraw"
4. Receive USDT + earned interest

:::warning
Withdrawals may be delayed if utilization is 100%. You'll receive funds as borrowers repay.
:::

---

## Staking LVG

### How to Stake

1. Go to "Stake" page
2. Enter LVG amount
3. Click "Stake"
4. Start earning rewards + fee discounts

### Claiming Rewards

Rewards accumulate in USDT. Click "Claim" anytime to receive them.

### Unstaking

No lock-up period. Unstake anytime, but you'll lose your fee discount tier.
