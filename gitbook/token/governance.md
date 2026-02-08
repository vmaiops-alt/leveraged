# Governance

*Governance features are coming soon. This page describes the planned system.*

## Overview

$LVG holders will be able to participate in protocol governance through on-chain voting.

## Governance Scope

### What Can Be Changed

| Category | Examples |
|----------|----------|
| Fees | Value fee %, entry fee %, liquidation bonus |
| Assets | Add/remove supported assets |
| Parameters | Max leverage, liquidation threshold |
| Treasury | Fund allocation, grants |
| Upgrades | Contract migrations |

### What Cannot Be Changed

- Core security mechanisms
- User fund access
- Existing position parameters

## Voting Power

Voting power is based on staked LVG:

```
Voting Power = Staked LVG Balance
```

### Delegation
You can delegate your voting power to another address.

## Proposal Process

### 1. Discussion (Off-chain)
- Forum post with proposal details
- Community feedback period (7 days)
- Informal temperature check

### 2. Proposal (On-chain)
Requirements:
- Minimum 100,000 LVG staked
- Proposal description
- Executable code (if applicable)

### 3. Voting Period
- Duration: 5 days
- Options: For / Against / Abstain

### 4. Timelock
- Delay: 2 days
- Allows users to exit if they disagree

### 5. Execution
Proposal is executed on-chain.

## Quorum

| Proposal Type | Quorum Required |
|---------------|-----------------|
| Standard | 4% of total supply |
| Critical | 10% of total supply |

## Timeline

```
Day 0-7     Day 7      Day 7-12    Day 12-14   Day 14
   │           │           │            │          │
   ▼           ▼           ▼            ▼          ▼
Discussion → Proposal → Voting → Timelock → Execution
```

## Planned Features

- [ ] Snapshot voting (gas-free)
- [ ] On-chain execution
- [ ] Delegation marketplace
- [ ] Proposal templates
- [ ] Governance rewards

## Current Status

Until full governance launches:
- Team multisig controls parameters
- Major changes announced in advance
- Community feedback collected via Discord

## Get Involved

1. Join [Discord](https://discord.gg/leveraged)
2. Participate in #governance channel
3. Share your ideas
4. Stay informed on proposals
