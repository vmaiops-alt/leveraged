# Audits

## Audit Status

| Auditor | Status | Date | Report |
|---------|--------|------|--------|
| TBD | 🟡 Scheduled | Q1 2026 | - |

## Scope

The audit will cover:

### Core Contracts
- LeveragedVault.sol
- LendingPool.sol
- ValueTracker.sol
- FeeCollector.sol

### Periphery
- Liquidator.sol
- PriceOracle.sol

### Token
- LVGToken.sol
- LVGStaking.sol

## Focus Areas

1. **Access Control** - Proper permission checks
2. **Math Operations** - Overflow/underflow protection
3. **Reentrancy** - External call safety
4. **Oracle Integration** - Price manipulation resistance
5. **Liquidation Logic** - Correctness and fairness
6. **Fee Calculations** - Accuracy of 25% value fee

## Internal Review

Prior to external audit, we conducted:

- ✅ Static analysis (Slither)
- ✅ Unit test coverage
- ✅ Internal code review
- ✅ Testnet deployment and testing

## Post-Audit

After audit completion:

1. Address all findings
2. Re-audit critical fixes
3. Publish full report
4. Launch bug bounty program

## Previous Findings

*No external audits completed yet.*

---

:::warning
**Unaudited Code Warning**

These contracts have not been audited. Use at your own risk. Do not deposit funds you cannot afford to lose.
:::
