---
sidebar_position: 1
---
# Yield Strategies

The protocol includes yield strategy infrastructure for future yield-bearing positions.

## Overview

While current positions track asset prices synthetically, the strategy system enables:
- Deploying idle capital to yield sources
- Auto-compounding rewards
- Diversified yield generation

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Strategy Manager                    │
│                                                     │
│   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │
│   │ PancakeSwap │ │   Venus     │ │   Future    │  │
│   │  Strategy   │ │  Strategy   │ │ Strategies  │  │
│   │             │ │             │ │             │  │
│   │  - LP Yield │ │ - Lending   │ │    ...      │  │
│   │  - CAKE     │ │ - XVS       │ │             │  │
│   └─────────────┘ └─────────────┘ └─────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Strategy Interface

All strategies implement:

```solidity
interface IStrategy {
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external returns (uint256);
    function harvest() external returns (uint256);
    function getTVL() external view returns (uint256);
    function getAPY() external view returns (uint256);
}
```

## Current Strategies

### PancakeSwap Strategy

Deploys funds to PancakeSwap LP pools:
- Earns trading fees
- Earns CAKE rewards
- Auto-compounds

### Venus Strategy

Lends on Venus Protocol:
- Earns supply APY
- Earns XVS rewards
- Low risk, lower yield

## Strategy Allocation

The StrategyManager distributes funds based on configured weights:

| Strategy | Allocation | Target APY |
|----------|------------|------------|
| PancakeSwap | 40% | 15-25% |
| Venus | 30% | 5-10% |
| Reserve | 30% | 0% |

Reserve ensures liquidity for withdrawals.

## Risk Management

### Diversification
No single strategy receives >50% of funds.

### Monitoring
- APY tracking
- TVL changes
- Strategy health checks

### Emergency
Strategies can be paused and funds withdrawn to safety.

## Future Strategies

Planned integrations:
- [ ] Alpaca Finance
- [ ] Biswap
- [ ] Stargate (cross-chain)
- [ ] GMX (on Arbitrum expansion)

## For Developers

### Adding a Strategy

1. Implement `IStrategy` interface
2. Deploy strategy contract
3. Admin adds via `addStrategy()`
4. Configure allocation weight

See [Integration Guide](../developers/integration.md) for details.
