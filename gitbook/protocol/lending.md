# Lending Pool

The **LendingPool** provides liquidity for leveraged trading and earns yield for depositors.

## Overview

The lending pool:
- Accepts USDT deposits from lenders
- Provides loans to the vault for leverage
- Accrues interest for lenders
- Manages utilization and interest rates

## How It Works

```
┌─────────────┐
│   Lenders   │
│             │
│  Deposit    │─────────────────┐
│  USDT      │                 │
└─────────────┘                 ▼
                        ┌──────────────┐
                        │              │
                        │   Lending    │
                        │    Pool      │
                        │              │
                        └──────┬───────┘
                               │
┌─────────────┐                │ Borrow
│   Traders   │ ◄──────────────┘
│             │
│  Leverage   │
│  Positions  │
└─────────────┘
```

## Depositing

### Process

1. User approves USDT spending
2. User calls `deposit(amount)`
3. Pool transfers USDT from user
4. User receives "shares" representing their deposit

### Share Calculation

```
shares = deposit × totalShares / totalAssets
```

If pool is empty: `shares = deposit`

### Example

```
Pool State:
- Total Assets: 100,000 USDT
- Total Shares: 100,000

User deposits 10,000 USDT
Shares received: 10,000 × 100,000 / 100,000 = 10,000 shares
```

## Withdrawing

### Process

1. User calls `withdraw(shares)`
2. Pool calculates USDT value
3. Pool transfers USDT to user (if available)
4. User's shares are burned

### Value Calculation

```
value = shares × totalAssets / totalShares
```

### Example

```
Pool State (after interest):
- Total Assets: 110,000 USDT
- Total Shares: 100,000

User withdraws 10,000 shares
Value received: 10,000 × 110,000 / 100,000 = 11,000 USDT
Profit: 1,000 USDT (10%)
```

## Interest Rate Model

### Utilization Rate

```
Utilization = Total Borrowed / Total Deposits × 100%
```

### Interest Curve

We use a **kinked interest rate model**:

| Utilization | Borrow APR |
|-------------|------------|
| 0% | 2% |
| 40% | 7% |
| 80% | 12% |
| 90% | 57% |
| 95% | 79% |
| 100% | 102% |

The kink at 80% utilization encourages healthy liquidity.

```
             │
      100% ──┤                              ╱
             │                            ╱
             │                          ╱
       50% ──┤                       ╱
             │                    ╱
             │              ╱ ─ ─ ─ Kink (80%)
       12% ──┤          ╱
             │      ╱
        2% ──┤──╱
             │
             └────────────────────────────────
             0%      50%      80%     100%
                      Utilization
```

### Supply APY

Lenders earn based on utilization:

```
Supply APY = Borrow APR × Utilization
```

| Utilization | Borrow APR | Supply APY |
|-------------|------------|------------|
| 50% | 7% | 3.5% |
| 70% | 10% | 7% |
| 80% | 12% | 9.6% |
| 90% | 57% | 51.3% |

## Borrowing (Internal)

Only the vault contract can borrow:

```solidity
function borrow(uint256 amount, address onBehalfOf) external onlyVault;
function repay(uint256 amount, address onBehalfOf) external onlyVault;
```

### Borrow Process

1. Vault opens leveraged position
2. Vault calls `borrow()` for needed leverage
3. Pool tracks debt per user
4. Interest accrues over time

### Repay Process

1. Position is closed
2. Vault calls `repay()` with principal + interest
3. Pool receives funds
4. User debt is cleared

## Interest Accrual

Interest compounds per second:

```
newDebt = oldDebt × (1 + APR / secondsPerYear) ^ secondsElapsed
```

## Pool Parameters

| Parameter | Value |
|-----------|-------|
| Base Rate | 2% APR |
| Slope 1 | 12.5% (0-80% util) |
| Slope 2 | 440% (80-100% util) |
| Optimal Utilization | 80% |

## View Functions

| Function | Returns |
|----------|---------|
| `getTotalDeposits()` | Total USDT in pool |
| `getTotalBorrowed()` | Total USDT borrowed |
| `getUtilizationRate()` | Current utilization (BPS) |
| `getCurrentAPY()` | Current supply APY (BPS) |
| `getDepositedAmount(user)` | User's deposit value |
| `getBorrowedAmount(user)` | User's debt value |

## Events

```solidity
event Deposited(
    address indexed user,
    uint256 amount,
    uint256 shares
);

event Withdrawn(
    address indexed user,
    uint256 amount,
    uint256 shares
);

event Borrowed(
    address indexed borrower,
    uint256 amount
);

event Repaid(
    address indexed borrower,
    uint256 amount
);
```

## Risks

### Utilization Risk
If utilization hits 100%, lenders cannot withdraw until borrowers repay.

### Smart Contract Risk
Bugs could affect funds. We recommend not depositing more than you can afford to lose until contracts are audited.

### Interest Rate Risk
APY fluctuates with utilization. High yields often mean high utilization (less liquidity).
