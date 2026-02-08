# API Reference

Complete reference for all contract functions.

## LeveragedVault

### Write Functions

#### openPosition
Opens a new leveraged position.

```solidity
function openPosition(
    address asset,
    uint256 amount,
    uint256 leverage
) external returns (uint256 positionId)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| asset | address | Asset to track (BTC, ETH, BNB) |
| amount | uint256 | USDT deposit amount |
| leverage | uint256 | Leverage in BPS (10000-50000) |

#### closePosition
Closes an existing position.

```solidity
function closePosition(uint256 positionId) external
```

#### addCollateral
Adds collateral to improve health factor.

```solidity
function addCollateral(uint256 positionId, uint256 amount) external
```

### Read Functions

#### getPosition
Returns position details.

```solidity
function getPosition(uint256 positionId) external view returns (Position memory)
```

#### getUserPositions
Returns all position IDs for a user.

```solidity
function getUserPositions(address user) external view returns (uint256[] memory)
```

#### getHealthFactor
Returns health factor in BPS (10000 = 1.0).

```solidity
function getHealthFactor(uint256 positionId) external view returns (uint256)
```

#### getPositionPnL
Returns current P&L.

```solidity
function getPositionPnL(uint256 positionId) external view returns (int256 pnl, int256 pnlPercent)
```

---

## LendingPool

### Write Functions

#### deposit
Deposits USDT to earn yield.

```solidity
function deposit(uint256 amount) external
```

#### withdraw
Withdraws USDT and earned interest.

```solidity
function withdraw(uint256 shares) external returns (uint256 amount)
```

### Read Functions

#### getTotalDeposits
```solidity
function getTotalDeposits() external view returns (uint256)
```

#### getTotalBorrowed
```solidity
function getTotalBorrowed() external view returns (uint256)
```

#### getUtilizationRate
Returns utilization in BPS.

```solidity
function getUtilizationRate() external view returns (uint256)
```

#### getCurrentAPY
Returns supply APY in BPS.

```solidity
function getCurrentAPY() external view returns (uint256)
```

#### getDepositedAmount
```solidity
function getDepositedAmount(address user) external view returns (uint256)
```

---

## LVGStaking

### Write Functions

#### stake
```solidity
function stake(uint256 amount) external
```

#### unstake
```solidity
function unstake(uint256 amount) external
```

#### claimRewards
```solidity
function claimRewards() external returns (uint256 amount)
```

### Read Functions

#### getStakedAmount
```solidity
function getStakedAmount(address user) external view returns (uint256)
```

#### getPendingRewards
```solidity
function getPendingRewards(address user) external view returns (uint256)
```

#### getFeeDiscount
Returns discount in BPS.

```solidity
function getFeeDiscount(address user) external view returns (uint256)
```

#### totalStaked
```solidity
function totalStaked() external view returns (uint256)
```

---

## Liquidator

### Write Functions

#### liquidate
```solidity
function liquidate(uint256 positionId) external returns (uint256 debtRepaid, uint256 collateralSeized)
```

#### batchLiquidate
```solidity
function batchLiquidate(uint256[] calldata positionIds) external returns (uint256 totalDebt, uint256 totalCollateral)
```

### Read Functions

#### getLiquidatablePositions
```solidity
function getLiquidatablePositions(uint256 maxPositions) external view returns (uint256[] memory)
```

#### estimateLiquidationReward
```solidity
function estimateLiquidationReward(uint256 positionId) external view returns (uint256)
```

---

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| MIN_LEVERAGE | 10000 | 1x minimum |
| MAX_LEVERAGE | 50000 | 5x maximum |
| ENTRY_FEE_BPS | 10 | 0.1% entry fee |
| VALUE_FEE_BPS | 2500 | 25% value fee |
| LIQUIDATION_THRESHOLD | 11000 | 110% health |
| LIQUIDATION_BONUS | 500 | 5% bonus |
