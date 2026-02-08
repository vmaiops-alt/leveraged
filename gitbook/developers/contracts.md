# Smart Contracts

## Core Contracts

### LeveragedVault

Main vault managing leveraged positions.

```solidity
// Open a leveraged position
function openPosition(
    address asset,
    uint256 amount,
    uint256 leverage
) external returns (uint256 positionId);

// Close a position
function closePosition(uint256 positionId) external;

// Add collateral to position
function addCollateral(uint256 positionId, uint256 amount) external;

// View functions
function getPosition(uint256 positionId) external view returns (Position memory);
function getUserPositions(address user) external view returns (uint256[] memory);
function getHealthFactor(uint256 positionId) external view returns (uint256);
function isLiquidatable(uint256 positionId) external view returns (bool);
```

### LendingPool

Manages deposits and borrows.

```solidity
// Deposit USDT
function deposit(uint256 amount) external;

// Withdraw USDT
function withdraw(uint256 shares) external returns (uint256);

// View functions
function getTotalDeposits() external view returns (uint256);
function getTotalBorrowed() external view returns (uint256);
function getUtilizationRate() external view returns (uint256);
function getCurrentAPY() external view returns (uint256);
function getDepositedAmount(address user) external view returns (uint256);
```

### FeeCollector

Collects and distributes protocol fees.

```solidity
// Distribute accumulated fees
function distributeFees() external;
function distributeToken(address token) external;

// View functions
function getPendingFees(address token) external view returns (uint256);
function getFeeRatios() external view returns (
    uint256 treasuryRatio,
    uint256 insuranceRatio,
    uint256 stakerRatio
);
```

### Liquidator

Manages position liquidations.

```solidity
// Liquidate unhealthy position
function liquidate(uint256 positionId) external returns (
    uint256 debtRepaid,
    uint256 collateralSeized
);

// Batch liquidation
function batchLiquidate(uint256[] calldata positionIds) external returns (
    uint256 totalDebtRepaid,
    uint256 totalCollateralSeized
);

// View functions
function getLiquidatablePositions(uint256 maxPositions) external view returns (uint256[] memory);
function isKeeper(address keeper) external view returns (bool);
function estimateLiquidationReward(uint256 positionId) external view returns (uint256);
```

## Token Contracts

### LVGToken

ERC-20 governance token.

```solidity
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function transfer(address to, uint256 amount) external returns (bool);
function approve(address spender, uint256 amount) external returns (bool);
function burn(uint256 amount) external;
```

### LVGStaking

Staking for rewards and fee discounts.

```solidity
// Stake LVG
function stake(uint256 amount) external;

// Unstake LVG
function unstake(uint256 amount) external;

// Claim USDT rewards
function claimRewards() external returns (uint256);

// View functions
function getStakedAmount(address user) external view returns (uint256);
function getPendingRewards(address user) external view returns (uint256);
function getFeeDiscount(address user) external view returns (uint256);
function totalStaked() external view returns (uint256);
```

## Periphery Contracts

### PriceOracle

Chainlink price feed integration.

```solidity
function getPrice(address asset) external view returns (uint256);
function priceFeeds(address asset) external view returns (address);
```

### ValueTracker

Tracks position value changes.

```solidity
function recordEntry(uint256 positionId, address asset, uint256 exposure) external;
function calculateValueIncrease(uint256 positionId, uint256 currentPrice) external view returns (
    uint256 valueIncrease,
    uint256 platformFee,
    uint256 userValueGain
);
```

## Events

### LeveragedVault Events

```solidity
event PositionOpened(uint256 indexed positionId, address indexed user, address asset, uint256 depositAmount, uint256 leverage, uint256 entryPrice);
event PositionClosed(uint256 indexed positionId, address indexed user, uint256 exitPrice, uint256 valueIncrease, uint256 platformFee, uint256 userPayout);
event PositionLiquidated(uint256 indexed positionId, address indexed user, address liquidator, uint256 exitPrice);
event CollateralAdded(uint256 indexed positionId, uint256 amount);
```

### LendingPool Events

```solidity
event Deposited(address indexed user, uint256 amount, uint256 shares);
event Withdrawn(address indexed user, uint256 amount, uint256 shares);
```

### Staking Events

```solidity
event Staked(address indexed user, uint256 amount);
event Unstaked(address indexed user, uint256 amount);
event RewardsClaimed(address indexed user, uint256 amount);
```

## Error Codes

| Error | Description |
|-------|-------------|
| `NotOwner` | Caller is not contract owner |
| `Paused` | Contract is paused |
| `InvalidLeverage` | Leverage not in 1x-5x range |
| `AssetNotSupported` | Asset not whitelisted |
| `NotPositionOwner` | Not owner of position |
| `NotLiquidatable` | Health factor too high |
| `InsufficientBalance` | Not enough tokens |
