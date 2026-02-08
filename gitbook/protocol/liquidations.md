# Liquidations

Liquidations protect the protocol from bad debt when positions become unhealthy.

## Health Factor

The health factor measures a position's safety:

```
Health Factor = Position Value / Total Debt
```

| Health Factor | Status | Action |
|---------------|--------|--------|
| > 1.5 | 🟢 Safe | None needed |
| 1.1 - 1.5 | 🟡 Warning | Consider adding collateral |
| < 1.1 | 🔴 Liquidatable | Can be liquidated |

## When Liquidation Occurs

A position becomes liquidatable when:

1. **Asset price drops** significantly
2. **Interest accrues** and increases debt
3. **High leverage** amplifies losses

### Example

```
Initial Position:
- Deposit: $1,000
- Leverage: 5x
- Total Exposure: $5,000
- Borrowed: $4,000
- BTC Price: $50,000
- Health Factor: 1.25

After 20% BTC Drop:
- BTC Price: $40,000
- Position Value: $4,000
- Debt: $4,000
- Health Factor: 1.0 (liquidatable!)
```

## Liquidation Process

### Step 1: Detection
Keeper bots continuously monitor all positions for low health factors.

### Step 2: Execution
When health < 1.1, keeper calls `liquidate(positionId)`.

### Step 3: Settlement
```
1. Get current position value
2. Repay debt to lending pool
3. Pay 5% bonus to liquidator
4. Send remainder to insurance fund
```

### Step 4: Closure
Position is marked as inactive and closed.

## Liquidation Bonus

Liquidators receive a **5% bonus** as incentive:

```
Position Value: $4,000
Debt: $3,800
Liquidator Bonus (5%): $200
```

## Keeper System

### Who Are Keepers?
Keepers are external accounts authorized to execute liquidations.

### How to Become a Keeper
1. Contact the team
2. Get whitelisted
3. Run keeper bot software

### Keeper Mode
The protocol can operate in two modes:

| Mode | Who Can Liquidate |
|------|-------------------|
| Public | Anyone |
| Keeper Only | Whitelisted keepers only |

## Avoiding Liquidation

### 1. Use Lower Leverage
Lower leverage = more buffer before liquidation.

| Leverage | Price Drop to Liquidation |
|----------|--------------------------|
| 2x | ~42% |
| 3x | ~28% |
| 4x | ~21% |
| 5x | ~17% |

### 2. Monitor Health Factor
Check your positions regularly. Set up alerts.

### 3. Add Collateral
If health factor is dropping, add more USDT collateral.

### 4. Close Early
If you expect continued losses, close manually before liquidation.

## Batch Liquidation

The Liquidator contract supports batch liquidations:

```solidity
function batchLiquidate(uint256[] calldata positionIds) external;
```

This allows keepers to efficiently liquidate multiple positions in one transaction.

## Insurance Fund

After liquidation:
- If position value > debt + bonus: remainder goes to insurance fund
- If position value < debt: insurance fund covers the bad debt

The insurance fund is built from:
- 30% of all platform fees
- Liquidation remainders

## Events

```solidity
event LiquidationExecuted(
    uint256 indexed positionId,
    address indexed liquidator,
    uint256 debtRepaid,
    uint256 collateralSeized,
    uint256 liquidatorBonus
);
```

## FAQ

**Q: Can I liquidate my own position?**
A: No, you should close it normally to retain any remaining value.

**Q: What happens to my deposit after liquidation?**
A: It goes to repaying debt and liquidator bonus. You likely receive nothing.

**Q: How fast do liquidations happen?**
A: Typically within seconds of becoming liquidatable, as keepers are incentivized.
