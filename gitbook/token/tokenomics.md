# Tokenomics

## Overview

**$LVG** is the native utility and governance token of the LEVERAGED protocol.

| Property | Value |
|----------|-------|
| Name | Leveraged |
| Symbol | LVG |
| Decimals | 18 |
| Max Supply | 100,000,000 |
| Chain | BNB Smart Chain |

## Token Distribution

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│    ████████████████████████████████████  40%       │
│    Farming/Staking Rewards                          │
│                                                     │
│    ████████████████████  20%                       │
│    Treasury                                         │
│                                                     │
│    ███████████████  15%                            │
│    Team                                             │
│                                                     │
│    ██████████  10%                                 │
│    Liquidity                                        │
│                                                     │
│    ██████████  10%                                 │
│    Private Sale                                     │
│                                                     │
│    █████  5%                                       │
│    Airdrop                                          │
│                                                     │
└─────────────────────────────────────────────────────┘
```

| Allocation | Amount | Percentage | Vesting |
|------------|--------|------------|---------|
| Farming/Staking | 40,000,000 | 40% | 4 years linear |
| Treasury | 20,000,000 | 20% | DAO controlled |
| Team | 15,000,000 | 15% | 2 year cliff, 2 year vest |
| Liquidity | 10,000,000 | 10% | At launch |
| Private Sale | 10,000,000 | 10% | 6 month cliff, 12 month vest |
| Airdrop | 5,000,000 | 5% | At launch |

## Emission Schedule

### Farming Rewards

40M tokens distributed over 4 years:

| Year | Emission | Cumulative |
|------|----------|------------|
| Year 1 | 16,000,000 | 16M |
| Year 2 | 12,000,000 | 28M |
| Year 3 | 8,000,000 | 36M |
| Year 4 | 4,000,000 | 40M |

Emission rate: ~317 LVG per block (3s blocks)

### Supply Over Time

```
100M ─────────────────────────────────────────── Max Supply
      │                               ┌───────
      │                          ┌────┘
 75M ─┤                    ┌─────┘
      │               ┌────┘
 50M ─┤          ┌────┘
      │     ┌────┘
 25M ─┤ ────┘
      │
   0 ─┴───────┬───────┬───────┬───────┬───────
          Launch   Y1      Y2      Y3      Y4
```

## Token Utility

### 1. Fee Discounts
Stake LVG to reduce the 25% value increase fee by up to 25%.

### 2. Revenue Sharing
20% of protocol fees distributed to LVG stakers.

### 3. Governance (Future)
Vote on protocol parameters, new assets, fee changes.

### 4. Liquidity Mining
Provide LVG liquidity to earn additional rewards.

## Initial Circulating Supply

At launch:
- Liquidity: 10,000,000
- Airdrop: 5,000,000
- **Total: 15,000,000 (15%)**

## Token Contract

```solidity
// Key functions
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);
function transfer(address to, uint256 amount) external returns (bool);
function burn(uint256 amount) external;
```

## Deflationary Mechanics

### Fee Buyback (Planned)
A portion of protocol revenue may be used to buy back and burn LVG.

### Staking Lock
Staked tokens are removed from circulation.

## Token Contract Address

| Network | Address |
|---------|---------|
| BSC Mainnet | TBD |
| BSC Testnet | TBD |

## Trading

### DEX
- PancakeSwap (primary)
- More DEXes TBA

### CEX
- Listings in progress

{% hint style="warning" %}
Always verify the token contract address. Beware of scams.
{% endhint %}
