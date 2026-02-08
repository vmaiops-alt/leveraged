# Risk Factors

Understanding the risks of using LEVERAGED.

## Smart Contract Risk

### Bugs
Despite testing and audits, bugs may exist that could result in loss of funds.

**Mitigation:**
- Multiple audits planned
- Bug bounty program
- Gradual rollout with caps

### Upgradability
Contracts are not upgradeable. Bugs cannot be patched in place.

**Mitigation:**
- Migration paths for critical fixes
- Insurance fund for affected users

## Market Risk

### Liquidation
High leverage positions can be liquidated quickly during volatile markets.

| Leverage | Price Drop to Liquidation |
|----------|--------------------------|
| 2x | ~42% |
| 3x | ~28% |
| 4x | ~21% |
| 5x | ~17% |

**Mitigation:**
- Use lower leverage
- Monitor positions
- Add collateral early

### Volatility
Crypto markets are highly volatile. Prices can move against you rapidly.

**Mitigation:**
- Only trade what you can afford to lose
- Understand leverage multiplies losses

## Oracle Risk

### Price Manipulation
If oracle prices are manipulated, positions could be unfairly liquidated.

**Mitigation:**
- Chainlink decentralized oracles
- Multiple data sources
- Staleness checks

### Downtime
If oracles fail, the protocol may be unable to function.

**Mitigation:**
- Chainlink high availability
- Fallback oracles planned

## Liquidity Risk

### Lending Pool
If utilization hits 100%, lenders cannot withdraw until borrowers repay.

**Mitigation:**
- Interest rate spikes discourage high utilization
- Protocol reserves planned

### LVG Token
Low liquidity could make it difficult to buy/sell LVG.

**Mitigation:**
- Protocol-owned liquidity
- Multiple DEX pairs

## Regulatory Risk

DeFi regulation is evolving. Future regulations could affect the protocol.

**Mitigation:**
- Decentralized architecture
- No KYC required
- Community governance

## Counterparty Risk

### USDT
The protocol relies on USDT. If USDT depegs, positions could be affected.

**Mitigation:**
- USDT is widely used and backed
- Future multi-collateral support

### BSC
The protocol runs on BNB Smart Chain. Chain issues could affect operations.

**Mitigation:**
- BSC is established with high uptime
- Multi-chain expansion planned

## Key Takeaways

1. **Never invest more than you can afford to lose**
2. **Understand leverage amplifies both gains AND losses**
3. **Monitor your positions regularly**
4. **Start small and learn the platform**
5. **DYOR - This is not financial advice**

---

:::danger
**Risk Warning**

Leveraged trading is extremely risky. You can lose your entire deposit. Past performance does not indicate future results. This documentation is for informational purposes only and does not constitute financial advice.
:::
