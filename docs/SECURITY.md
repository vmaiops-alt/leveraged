# LEVERAGED Security Documentation

## Overview

This document outlines security considerations, attack vectors, and mitigations for the LEVERAGED protocol.

## Architecture Security

### Access Control

| Contract | Admin Functions | Protected By |
|----------|-----------------|--------------|
| LeveragedVault | pause, setSupportedAsset, setFeeCollector | onlyOwner |
| LendingPool | setVault, setInterestRateModel | onlyOwner |
| FeeCollector | setFeeRatios, emergencyWithdraw | onlyOwner |
| Liquidator | addKeeper, setKeeperOnlyMode | onlyOwner |
| LVGToken | setMinter, initialDistribution | onlyOwner |
| LVGStaking | setFeeCollector, emergencyWithdraw | onlyOwner |

**Recommendation:** Transfer ownership to multisig (3/5) before mainnet launch.

### Pausability

All core contracts implement pause functionality:
- `LeveragedVault.pause()` - Stops new positions, liquidations continue
- `LendingPool.pause()` - Stops deposits/withdraws
- `FeeCollector.pause()` - Stops fee collection
- `Liquidator.pause()` - Stops liquidations

**Emergency Response:**
1. Pause affected contract(s)
2. Assess damage
3. Deploy fix if needed
4. Unpause after verification

## Attack Vectors & Mitigations

### 1. Price Oracle Manipulation

**Risk:** Flash loan attacks manipulating oracle prices

**Mitigations:**
- Chainlink oracles with multiple data sources
- Staleness checks (revert if price > 1 hour old)
- Heartbeat validation
- Consider TWAP for additional protection

```solidity
// PriceOracle.sol
require(block.timestamp - updatedAt <= MAX_STALENESS, "Stale price");
```

### 2. Flash Loan Attacks

**Risk:** Borrow → manipulate → profit in single tx

**Mitigations:**
- No same-block position open/close
- Minimum position duration (optional)
- Health factor checks use oracle prices, not pool balances

### 3. Reentrancy

**Risk:** Callback during token transfer drains funds

**Mitigations:**
- Solidity 0.8+ (no overflow)
- Checks-Effects-Interactions pattern
- State updates before external calls
- Consider ReentrancyGuard for critical functions

### 4. Liquidation Front-Running

**Risk:** MEV bots front-run liquidations

**Mitigations:**
- Keeper-only mode available
- Private mempool submission (Flashbots)
- Liquidation bonus incentivizes timely liquidation

### 5. Interest Rate Manipulation

**Risk:** Whale deposits/withdraws to manipulate rates

**Mitigations:**
- Utilization-based interest model
- Rate bounds (min/max APY)
- Gradual rate changes

### 6. Governance Attacks

**Risk:** Malicious proposals or token concentration

**Mitigations:**
- Timelock on admin functions (planned)
- Multisig requirement
- Token distribution across many holders

## Invariants

These conditions must ALWAYS hold:

### LeveragedVault
```
∀ position: healthFactor >= 1.0 OR isLiquidatable == true
∀ position: borrowedAmount <= totalExposure - depositAmount
totalExposure == depositAmount * leverage / 10000
```

### LendingPool
```
totalDeposits >= totalBorrowed
utilizationRate == totalBorrowed / totalDeposits * 10000
∀ user: userDeposit <= totalDeposits
```

### FeeCollector
```
treasuryRatio + insuranceRatio + stakerRatio == 10000
pendingFees[token] <= token.balanceOf(feeCollector)
```

### LVGToken
```
totalSupply <= MAX_SUPPLY (100M)
farmingMinted <= FARMING_ALLOCATION (40M)
```

## Emergency Procedures

### Scenario 1: Oracle Failure
1. Monitor: Chainlink heartbeat stops
2. Action: Pause vault, disable new positions
3. Recovery: Switch to backup oracle or wait for recovery

### Scenario 2: Exploit Detected
1. Monitor: Unusual TVL changes, abnormal transactions
2. Action: Pause ALL contracts immediately
3. Recovery: Assess damage, snapshot state, plan fix

### Scenario 3: Bad Debt Accumulation
1. Monitor: Health factors approaching 1.0 system-wide
2. Action: Increase liquidation incentives, alert keepers
3. Recovery: Use insurance fund to cover bad debt

### Scenario 4: Smart Contract Bug
1. Monitor: Unexpected behavior in transactions
2. Action: Pause affected contract
3. Recovery: Deploy patched contract, migrate state if needed

## Audit Checklist

### Pre-Audit
- [ ] All tests passing
- [ ] 100% code coverage on critical paths
- [ ] NatSpec documentation complete
- [ ] No compiler warnings
- [ ] Static analysis clean (Slither)

### Audit Focus Areas
- [ ] Access control correctness
- [ ] Math operations (especially fee calculations)
- [ ] Oracle integration
- [ ] Liquidation logic
- [ ] Token transfer handling
- [ ] State consistency across contracts

### Post-Audit
- [ ] All findings addressed
- [ ] Re-audit critical fixes
- [ ] Bug bounty program launched
- [ ] Monitoring infrastructure ready

## Bug Bounty Program

**Planned Rewards:**
| Severity | Reward |
|----------|--------|
| Critical | $50,000 |
| High | $20,000 |
| Medium | $5,000 |
| Low | $1,000 |

**Scope:**
- All deployed smart contracts
- Frontend security (XSS, etc.)
- API security

**Out of Scope:**
- Already known issues
- Theoretical attacks without PoC
- Social engineering

## Monitoring

### On-Chain Metrics
- TVL changes > 10% in 1 hour
- Utilization rate > 95%
- Health factors < 1.2 for any position
- Unusual gas consumption
- Failed transactions spike

### Alerts
- PagerDuty integration for critical
- Telegram bot for warnings
- Daily summary reports

## Contact

Security issues: security@leveraged.finance (planned)
Bug bounty: bounty@leveraged.finance (planned)

**Do NOT disclose vulnerabilities publicly before contacting the team.**
