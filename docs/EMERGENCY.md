# Emergency Procedures

## Quick Reference

### Pause Commands (Owner Only)

```solidity
// Pause everything
LeveragedVault(VAULT).pause();
LendingPool(POOL).pause();
FeeCollector(FEES).pause();
Liquidator(LIQ).pause();

// Unpause
LeveragedVault(VAULT).unpause();
// ... etc
```

### Contract Addresses (Update After Deploy)

```
VAULT:      0x...
POOL:       0x...
FEES:       0x...
LIQUIDATOR: 0x...
LVG_TOKEN:  0x...
STAKING:    0x...
```

## Severity Levels

### 🔴 CRITICAL
- Active exploit draining funds
- Oracle returning zero/invalid prices
- Contract upgrade with backdoor

**Response Time:** Immediate (< 5 minutes)
**Actions:** Pause all, assess, communicate

### 🟠 HIGH  
- Suspicious large transactions
- Liquidation cascade starting
- Oracle delayed > 30 minutes

**Response Time:** < 30 minutes
**Actions:** Monitor closely, prepare pause, alert team

### 🟡 MEDIUM
- Utilization > 90%
- Single large position (> 10% TVL)
- Gas prices spiking

**Response Time:** < 2 hours
**Actions:** Monitor, adjust parameters if needed

### 🟢 LOW
- Minor UI issues
- Non-critical monitoring gaps
- Documentation updates needed

**Response Time:** < 24 hours
**Actions:** Log, schedule fix

## Scenario Playbooks

### 1. Oracle Manipulation Attack

**Indicators:**
- Price deviates > 5% from CEX prices
- Unusual liquidation volume
- Reports from community

**Steps:**
1. `vault.pause()` - Stop new positions
2. Check Chainlink status page
3. Compare on-chain vs off-chain prices
4. If manipulation confirmed:
   - Keep paused
   - Document affected positions
   - Prepare compensation plan
5. If false alarm:
   - `vault.unpause()`
   - Post-mortem on detection

### 2. Smart Contract Exploit

**Indicators:**
- Unexpected balance changes
- Failed invariant checks
- Community reports of losses

**Steps:**
1. PAUSE ALL CONTRACTS IMMEDIATELY
   ```
   vault.pause()
   pool.pause()
   feeCollector.pause()
   liquidator.pause()
   ```
2. Identify attack vector
3. Snapshot current state
4. Estimate damages
5. Communicate to community (Twitter, Discord)
6. Engage security researchers
7. Plan recovery:
   - Fix vulnerability
   - Deploy new contracts
   - Migrate user funds
   - Compensate affected users

### 3. Mass Liquidation Event

**Indicators:**
- Market crash > 20%
- Multiple positions at health < 1.2
- Liquidator queue building

**Steps:**
1. Monitor closely (DO NOT pause - liquidations protect protocol)
2. Ensure keeper bots are running
3. Consider temporarily increasing liquidation bonus
4. If bad debt accumulating:
   - Use insurance fund
   - Consider protocol-owned liquidations
5. Post-event: analyze and adjust parameters

### 4. Lending Pool Bank Run

**Indicators:**
- Utilization hits 100%
- Withdraw queue forming
- Community panic

**Steps:**
1. DO NOT PAUSE (makes panic worse)
2. Communicate clearly:
   - Funds are safe
   - Borrowers paying interest
   - Withdrawals process as loans repaid
3. Consider emergency rate adjustment:
   - Spike borrow rate to encourage repayment
4. If protocol has reserves, inject liquidity

### 5. Key Compromise

**Indicators:**
- Unauthorized transactions from admin
- Multisig signer reports compromise

**Steps:**
1. Immediately pause all contracts (if still possible)
2. Rotate compromised keys
3. If multisig: remove compromised signer
4. If single owner: deploy new contracts, migrate
5. Forensic analysis of compromise
6. Report to law enforcement if applicable

### 6. Frontend Compromise

**Indicators:**
- Users report phishing
- Unexpected contract interactions
- DNS/CDN anomalies

**Steps:**
1. Take frontend offline immediately
2. Alert users via Twitter/Discord:
   - "Do not interact with frontend"
   - "Revoke approvals at revoke.cash"
3. Investigate compromise vector
4. Redeploy from verified source
5. Verify no contract-level compromise

## Communication Templates

### Pause Announcement
```
🚨 LEVERAGED PROTOCOL PAUSED

We have temporarily paused the protocol due to [REASON].

Your funds are SAFE. This is a precautionary measure.

We are investigating and will provide updates every [TIMEFRAME].

DO NOT interact with any unofficial links.
Official channels only: [LINKS]
```

### Exploit Confirmed
```
🔴 SECURITY INCIDENT

We have identified a vulnerability affecting [SCOPE].

IMMEDIATE ACTIONS FOR USERS:
1. Do not deposit new funds
2. Revoke approvals: revoke.cash
3. Follow official channels only

WHAT WE'RE DOING:
1. Protocol is paused
2. Security team engaged
3. Developing recovery plan

Estimated damages: [AMOUNT]
Affected users: [COUNT]

We will share a full post-mortem within 48 hours.
```

### All Clear
```
✅ PROTOCOL RESUMED

The issue has been resolved. Protocol is now operational.

Summary:
- Issue: [DESCRIPTION]
- Duration: [TIME]
- Impact: [IMPACT]
- Resolution: [FIX]

Full post-mortem: [LINK]

Thank you for your patience.
```

## Post-Incident

### Within 24 Hours
- [ ] Incident documented
- [ ] Root cause identified
- [ ] Fix deployed (if applicable)
- [ ] Community updated

### Within 1 Week
- [ ] Full post-mortem published
- [ ] Compensation plan (if applicable)
- [ ] Process improvements identified
- [ ] Monitoring enhanced

### Within 1 Month
- [ ] External audit of fix
- [ ] Bug bounty adjustments
- [ ] Team training updated
- [ ] Runbook improvements

## Contacts

| Role | Contact | Backup |
|------|---------|--------|
| Lead Dev | TBD | TBD |
| Security | TBD | TBD |
| Comms | TBD | TBD |
| Legal | TBD | TBD |

## Tools

- **Tenderly:** Transaction simulation & debugging
- **Etherscan:** Contract verification & interaction  
- **Revoke.cash:** Help users revoke approvals
- **Flashbots Protect:** Private transaction submission
- **Dune:** Analytics dashboards
