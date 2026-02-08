---
sidebar_position: 1
---
# Price Oracles

LEVERAGED uses Chainlink price feeds for accurate, manipulation-resistant pricing.

## Why Chainlink?

- **Decentralized**: Multiple independent node operators
- **Reliable**: Industry standard, battle-tested
- **Accurate**: Aggregated from multiple data sources
- **Timely**: Frequent updates (heartbeat)

## Supported Price Feeds

### BSC Mainnet

| Asset | Feed Address | Decimals |
|-------|--------------|----------|
| BTC/USD | `0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf` | 8 |
| ETH/USD | `0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e` | 8 |
| BNB/USD | `0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE` | 8 |

### BSC Testnet

| Asset | Feed Address | Decimals |
|-------|--------------|----------|
| BTC/USD | `0x5741306c21795FdCBb9b265Ea0255F499DFe515C` | 8 |
| ETH/USD | `0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7` | 8 |
| BNB/USD | `0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526` | 8 |

## Price Validation

Our oracle contract validates prices before use:

### 1. Staleness Check
```solidity
require(block.timestamp - updatedAt <= MAX_STALENESS, "Stale price");
```
Prices older than 1 hour are rejected.

### 2. Positive Check
```solidity
require(price > 0, "Invalid price");
```

### 3. Heartbeat Validation
```solidity
require(answeredInRound >= roundId, "Stale round");
```

## Price Flow

```
┌─────────────┐     Query      ┌─────────────┐
│  Chainlink  │ ◄───────────── │ PriceOracle │
│    Feed     │                │  Contract   │
│             │ ──────────────►│             │
│             │    Price       │  - Validate │
└─────────────┘                │  - Convert  │
                               └──────┬──────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
            ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
            │    Vault     │  │  Liquidator  │  │ Value Tracker│
            │ (positions)  │  │ (health)     │  │ (P&L calc)   │
            └──────────────┘  └──────────────┘  └──────────────┘
```

## Contract Interface

```solidity
interface IPriceOracle {
    /// @notice Get the current price for an asset
    /// @param asset The asset address
    /// @return price Price with 8 decimals
    function getPrice(address asset) external view returns (uint256);
    
    /// @notice Get price feed address for an asset
    /// @param asset The asset address
    /// @return feed Chainlink feed address
    function priceFeeds(address asset) external view returns (address);
}
```

## Admin Functions

### Set Price Feed
```solidity
function setPriceFeed(address asset, address feed) external onlyOwner;
```

Only the admin can add or update price feeds.

## Manipulation Resistance

### Why Not Use DEX Prices?

DEX prices (AMM spot prices) can be manipulated within a single transaction using flash loans. An attacker could:

1. Flash loan large amount
2. Manipulate DEX price
3. Open/close leveraged position at manipulated price
4. Profit

### Chainlink Protection

Chainlink aggregates prices from:
- Multiple exchanges (CEX + DEX)
- Multiple node operators
- Over time (not instant)

This makes flash loan attacks economically infeasible.

## Edge Cases

### Oracle Downtime
If Chainlink is down:
- Price queries revert
- No new positions can open
- Existing positions cannot close
- Protocol is effectively paused

### Price Deviation
If on-chain price deviates significantly from market:
- Users may be unfairly liquidated
- Arbitrage opportunities exist
- Team monitors for anomalies

## Future Improvements

- [ ] Fallback oracles (Pyth, Band)
- [ ] TWAP integration
- [ ] Circuit breakers for large deviations
- [ ] Multi-oracle consensus
