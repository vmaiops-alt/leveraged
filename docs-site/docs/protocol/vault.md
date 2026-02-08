---
sidebar_position: 1
---
# Leveraged Vault

The **LeveragedVault** is the core contract that manages all leveraged positions.

## Overview

The vault handles:
- Opening leveraged positions
- Closing positions and calculating P&L
- Adding collateral to existing positions
- Position health tracking
- Integration with lending pool for leverage

## Position Structure

Each position contains:

```solidity
struct Position {
    address user;           // Position owner
    address asset;          // Tracked asset (BTC, ETH, BNB)
    uint256 depositAmount;  // User's collateral
    uint256 leverageMultiplier; // Leverage in BPS (10000 = 1x)
    uint256 totalExposure;  // Total position size
    uint256 borrowedAmount; // Amount borrowed from pool
    uint256 entryPrice;     // Asset price at open
    uint256 entryTimestamp; // When position opened
    bool isActive;          // Position status
}
```

## Opening a Position

### Parameters

| Parameter | Description |
|-----------|-------------|
| `asset` | Address of asset to track |
| `amount` | USDT deposit amount |
| `leverage` | Leverage in BPS (10000-50000) |

### Process

1. **Validation**
   - Asset is supported
   - Amount > 0
   - Leverage between 1x-5x

2. **Fee Deduction**
   - Entry fee (0.1%) deducted
   - Fee sent to FeeCollector

3. **Borrowing**
   - Calculate borrow amount: `(deposit × leverage) - deposit`
   - Borrow from LendingPool

4. **Price Recording**
   - Get current price from oracle
   - Record in ValueTracker

5. **Position Creation**
   - Store position data
   - Emit `PositionOpened` event

### Example

```
Deposit: 1,000 USDT
Leverage: 3x (30000 BPS)
Entry Fee: 1 USDT (0.1%)
Net Deposit: 999 USDT
Borrowed: 1,998 USDT
Total Exposure: 2,997 USDT
```

## Closing a Position

### Parameters

| Parameter | Description |
|-----------|-------------|
| `positionId` | ID of position to close |

### Process

1. **Ownership Check**
   - Only position owner can close

2. **Value Calculation**
   - Get current price from oracle
   - Calculate current position value
   - Compare to entry value

3. **Fee Calculation**
   - If profit: 25% value increase fee
   - If loss: no fee

4. **Debt Repayment**
   - Repay borrowed amount + interest to pool

5. **Payout**
   - Transfer remaining value to user
   - Mark position as inactive

### Example (Profit)

```
Entry Value: 2,997 USDT (at $50,000 BTC)
Current Value: 3,596 USDT (at $60,000 BTC)
Value Increase: 599 USDT
Platform Fee (25%): 150 USDT
Debt + Interest: 2,050 USDT
User Receives: 1,396 USDT
Net Profit: 397 USDT (+39.7%)
```

### Example (Loss)

```
Entry Value: 2,997 USDT (at $50,000 BTC)
Current Value: 2,398 USDT (at $40,000 BTC)
Value Decrease: -599 USDT
Platform Fee: 0 USDT
Debt + Interest: 2,050 USDT
User Receives: 348 USDT
Net Loss: -651 USDT (-65.1%)
```

## Adding Collateral

Users can add collateral to improve their health factor:

```solidity
function addCollateral(uint256 positionId, uint256 amount) external;
```

This:
1. Transfers USDT from user
2. Increases deposit amount
3. Increases total exposure
4. Improves health factor

## Health Factor

The health factor measures position safety:

```
Health Factor = Position Value / Total Debt
```

| Health Factor | Status |
|---------------|--------|
| > 1.5 | 🟢 Safe |
| 1.1 - 1.5 | 🟡 Warning |
| < 1.1 | 🔴 Liquidatable |

## Supported Assets

Assets must be whitelisted by admin:

```solidity
function setSupportedAsset(address asset, bool supported) external onlyOwner;
```

Current supported assets:
- WBTC (Bitcoin)
- WETH (Ethereum)
- WBNB (BNB)

## Events

```solidity
event PositionOpened(
    uint256 indexed positionId,
    address indexed user,
    address asset,
    uint256 depositAmount,
    uint256 leverage,
    uint256 entryPrice
);

event PositionClosed(
    uint256 indexed positionId,
    address indexed user,
    uint256 exitPrice,
    uint256 valueIncrease,
    uint256 platformFee,
    uint256 userPayout
);

event PositionLiquidated(
    uint256 indexed positionId,
    address indexed user,
    address liquidator,
    uint256 exitPrice
);

event CollateralAdded(
    uint256 indexed positionId,
    uint256 amount
);
```

## View Functions

| Function | Returns |
|----------|---------|
| `getPosition(id)` | Full position struct |
| `getUserPositions(user)` | Array of position IDs |
| `getHealthFactor(id)` | Current health factor |
| `isLiquidatable(id)` | Whether position can be liquidated |
| `getPositionPnL(id)` | Current P&L in USDT |

## Security Considerations

- Positions can only be closed by owner
- Liquidations have separate access control
- Pause functionality for emergencies
- Oracle validation before price usage
