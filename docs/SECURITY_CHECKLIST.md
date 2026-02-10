# LEVERAGED 2.0 — Security Review Checklist

**Date:** 2026-02-10  
**Auditor:** Nina (Security Engineer)  
**Status:** Pre-Audit Checklist

---

## Contracts in Scope

| Contract | Address | Risk Level |
|----------|---------|------------|
| LVGToken | `0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1` | Medium |
| LVGStaking | `0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F` | High |
| LendingPoolV5 | `0x088c08057D51B9C76B06102B95EF0555A1c44507` | Critical |
| LeveragedFarmV3 | `0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05` | Critical |
| YieldTokenizer | `0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605` | High |
| PerpVault | `0x2911013D3c842420fe5189C9166BDdd8aB6E444E` | Critical |
| PositionManager | `0xA93c5D73793F000F200B1c92C796207eE1948f50` | Critical |
| VotingEscrow | `0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D` | Medium |
| GaugeController | `0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5` | Medium |

---

## 1. Access Control

### General Checks
| Check | Status | Notes |
|-------|--------|-------|
| Owner/admin addresses are multisig | ☐ | Minimum 3/5 recommended |
| Two-step ownership transfer implemented | ☐ | Prevent accidental transfers |
| Role-based access (OpenZeppelin AccessControl) | ☐ | Check role hierarchy |
| Emergency pause functionality exists | ☐ | Who can pause? |
| Timelock on critical functions | ☐ | 24-48h recommended |

### Per-Contract Checks

#### LVGToken
| Check | Status | Notes |
|-------|--------|-------|
| Minting permissions restricted | ☐ | Who can mint? Cap exists? |
| Burn functionality safe | ☐ | Only owner burns or user burns own tokens? |
| Blacklist/whitelist functions audited | ☐ | If exists, check for abuse |

#### LVGStaking
| Check | Status | Notes |
|-------|--------|-------|
| Reward distribution only by authorized | ☐ | |
| Withdrawal functions not admin-gated | ☐ | Users must always be able to withdraw |
| Emergency withdrawal exists | ☐ | Bypasses lockup if needed |

#### LendingPoolV5
| Check | Status | Notes |
|-------|--------|-------|
| Collateral ratio changes timelocked | ☐ | Prevent rug via parameter change |
| Interest rate model admin restricted | ☐ | |
| Reserve factor changes limited | ☐ | |

#### LeveragedFarmV3
| Check | Status | Notes |
|-------|--------|-------|
| Strategy changes timelocked | ☐ | |
| Leverage limits admin-only | ☐ | |
| Fee changes capped | ☐ | Max fee limit hardcoded? |

#### YieldTokenizer
| Check | Status | Notes |
|-------|--------|-------|
| Token minting matches deposits 1:1 | ☐ | |
| Redemption always possible | ☐ | |

#### PerpVault
| Check | Status | Notes |
|-------|--------|-------|
| Position limits enforced | ☐ | |
| Margin requirements non-zero | ☐ | |
| Liquidator whitelist (if any) reviewed | ☐ | |

#### PositionManager
| Check | Status | Notes |
|-------|--------|-------|
| Only authorized contracts can modify positions | ☐ | |
| User can always close own position | ☐ | |

#### VotingEscrow
| Check | Status | Notes |
|-------|--------|-------|
| Lock duration bounds checked | ☐ | Min/max reasonable? |
| Early unlock penalty clear | ☐ | |

#### GaugeController
| Check | Status | Notes |
|-------|--------|-------|
| Gauge addition/removal admin-only | ☐ | |
| Weight changes timelocked | ☐ | |

---

## 2. Reentrancy Protection

### General Checks
| Check | Status | Notes |
|-------|--------|-------|
| `nonReentrant` modifier on all external value-handling functions | ☐ | |
| CEI pattern (Checks-Effects-Interactions) followed | ☐ | |
| No cross-function reentrancy vulnerabilities | ☐ | |
| No cross-contract reentrancy via callbacks | ☐ | |

### High-Risk Functions to Review

#### LVGStaking
| Function | nonReentrant | CEI Pattern | Notes |
|----------|--------------|-------------|-------|
| `stake()` | ☐ | ☐ | |
| `withdraw()` | ☐ | ☐ | |
| `claimRewards()` | ☐ | ☐ | |
| `exit()` | ☐ | ☐ | |

#### LendingPoolV5
| Function | nonReentrant | CEI Pattern | Notes |
|----------|--------------|-------------|-------|
| `deposit()` | ☐ | ☐ | |
| `withdraw()` | ☐ | ☐ | |
| `borrow()` | ☐ | ☐ | |
| `repay()` | ☐ | ☐ | |
| `liquidate()` | ☐ | ☐ | Critical! |

#### LeveragedFarmV3
| Function | nonReentrant | CEI Pattern | Notes |
|----------|--------------|-------------|-------|
| `openPosition()` | ☐ | ☐ | |
| `closePosition()` | ☐ | ☐ | |
| `addCollateral()` | ☐ | ☐ | |
| `removeCollateral()` | ☐ | ☐ | |

#### PerpVault
| Function | nonReentrant | CEI Pattern | Notes |
|----------|--------------|-------------|-------|
| `deposit()` | ☐ | ☐ | |
| `withdraw()` | ☐ | ☐ | |
| `openLong()` | ☐ | ☐ | |
| `openShort()` | ☐ | ☐ | |
| `closePosition()` | ☐ | ☐ | |

#### YieldTokenizer
| Function | nonReentrant | CEI Pattern | Notes |
|----------|--------------|-------------|-------|
| `tokenize()` | ☐ | ☐ | |
| `redeem()` | ☐ | ☐ | |

---

## 3. Oracle Security

### General Checks
| Check | Status | Notes |
|-------|--------|-------|
| Using Chainlink or other battle-tested oracle | ☐ | |
| Multiple price sources / TWAP fallback | ☐ | |
| Oracle addresses not hardcoded (upgradeable) | ☐ | |
| Circuit breakers for extreme price moves | ☐ | |

### Staleness Checks
| Check | Status | Notes |
|-------|--------|-------|
| `updatedAt` timestamp checked | ☐ | |
| Maximum staleness threshold defined | ☐ | Recommended: 1 hour for volatile assets |
| Transaction reverts on stale price | ☐ | |
| Sequencer uptime check (L2 only) | ☐ | If on Arbitrum/Optimism |

### Price Feed Validation
| Check | Status | Notes |
|-------|--------|-------|
| `answer > 0` validated | ☐ | |
| `answeredInRound >= roundId` checked | ☐ | |
| Decimals handled correctly | ☐ | 8 decimals for most Chainlink feeds |
| Price deviation limits (sanity bounds) | ☐ | Reject >50% deviation from last known |

### Per-Contract Oracle Usage

#### LendingPoolV5
| Check | Status | Notes |
|-------|--------|-------|
| Collateral valuation uses fresh prices | ☐ | |
| Liquidation uses same oracle as borrowing | ☐ | Prevent arbitrage |
| Borrow limit calculated correctly | ☐ | |

#### LeveragedFarmV3
| Check | Status | Notes |
|-------|--------|-------|
| LP token pricing accurate | ☐ | Use fair LP pricing formula |
| Underlying asset prices fresh | ☐ | |
| Leverage calculation uses spot, not manipulable | ☐ | |

#### PerpVault
| Check | Status | Notes |
|-------|--------|-------|
| Funding rate oracle separate from spot | ☐ | |
| Mark price vs index price spread limited | ☐ | |
| Settlement price manipulation resistant | ☐ | |

---

## 4. Liquidation Logic

### General Checks
| Check | Status | Notes |
|-------|--------|-------|
| Liquidation threshold < collateral factor | ☐ | Buffer for price moves |
| Partial liquidations supported | ☐ | Don't force full liquidation |
| Liquidation bonus reasonable (5-15%) | ☐ | Too high = drain protocol |
| Bad debt handling defined | ☐ | Insurance fund? Socialized loss? |
| Self-liquidation prevented or handled | ☐ | |

### LendingPoolV5 Specifics
| Check | Status | Notes |
|-------|--------|-------|
| Health factor calculation correct | ☐ | HF = (collateral * LT) / debt |
| Liquidation threshold per asset | ☐ | |
| Close factor reasonable (25-50%) | ☐ | Max liquidatable per tx |
| Liquidator receives correct bonus | ☐ | |
| Dust positions handled | ☐ | Min position size? |

### LeveragedFarmV3 Specifics
| Check | Status | Notes |
|-------|--------|-------|
| Leverage liquidation threshold clear | ☐ | |
| Position can be liquidated before underwater | ☐ | |
| Slippage during liquidation handled | ☐ | |

### PerpVault Specifics
| Check | Status | Notes |
|-------|--------|-------|
| Maintenance margin enforced | ☐ | |
| ADL (auto-deleveraging) mechanism | ☐ | For extreme cases |
| Insurance fund contribution | ☐ | From fees/liquidations |
| Liquidation price calculation correct | ☐ | |

### PositionManager Specifics
| Check | Status | Notes |
|-------|--------|-------|
| Aggregates positions correctly | ☐ | |
| Cross-margin handled properly | ☐ | |
| Liquidation priority fair | ☐ | |

---

## 5. Integer Overflow/Underflow

### General Checks
| Check | Status | Notes |
|-------|--------|-------|
| Solidity version ≥ 0.8.0 | ☐ | Built-in overflow protection |
| No `unchecked` blocks without review | ☐ | Each must be justified |
| `SafeMath` not used (redundant in 0.8+) | ☐ | Or justified if used |

### Critical Calculations to Verify

#### Interest/Yield Calculations
| Check | Status | Notes |
|-------|--------|-------|
| Compound interest doesn't overflow | ☐ | Use safe exponentiation |
| APY calculations bounded | ☐ | |
| Reward per share scaling correct | ☐ | Usually 1e18 or 1e36 |

#### Token Amount Calculations
| Check | Status | Notes |
|-------|--------|-------|
| Decimal handling consistent | ☐ | 6, 8, 18 decimal tokens |
| Division before multiplication avoided | ☐ | Precision loss |
| Rounding direction explicit | ☐ | roundUp for protocol, roundDown for user |

#### Timestamp Calculations
| Check | Status | Notes |
|-------|--------|-------|
| Block.timestamp used correctly | ☐ | |
| Duration calculations don't overflow | ☐ | Years * seconds |
| Time-weighted calculations safe | ☐ | |

### Per-Contract Checks

#### VotingEscrow
| Check | Status | Notes |
|-------|--------|-------|
| Lock time calculations safe | ☐ | Max 4 years typically |
| Voting power decay calculated correctly | ☐ | |
| Checkpoint math safe | ☐ | |

#### GaugeController
| Check | Status | Notes |
|-------|--------|-------|
| Weight calculations don't overflow | ☐ | |
| Epoch calculations correct | ☐ | |
| Total weight never zero (div by zero) | ☐ | |

---

## 6. Flash Loan Risks

### General Checks
| Check | Status | Notes |
|-------|--------|-------|
| Same-block deposit/withdraw restricted where needed | ☐ | |
| Governance votes require time-lock | ☐ | Prevent flash loan voting |
| Price oracle manipulation resistant | ☐ | TWAP or Chainlink |
| Share price manipulation prevented | ☐ | |

### Attack Vectors to Check

#### Share Price Manipulation
| Check | Status | Notes |
|-------|--------|-------|
| First depositor attack mitigated | ☐ | Min deposit or virtual shares |
| Donation attack prevented | ☐ | Can't inflate share price |
| Share calculation uses stored values | ☐ | Not manipulable balances |

#### Governance Manipulation
| Check | Status | Notes |
|-------|--------|-------|
| VotingEscrow requires lock before vote | ☐ | |
| Snapshot at proposal creation | ☐ | |
| Vote delegation time-delayed | ☐ | |

#### Liquidity Pool Manipulation
| Check | Status | Notes |
|-------|--------|-------|
| LP token price uses reserves correctly | ☐ | Fair LP pricing |
| Reward distribution not manipulable | ☐ | |
| Collateral valuation time-weighted | ☐ | |

### Per-Contract Checks

#### LendingPoolV5
| Check | Status | Notes |
|-------|--------|-------|
| Cannot borrow and liquidate same block | ☐ | |
| Interest accrual per block | ☐ | |
| Utilization rate manipulation checked | ☐ | |

#### YieldTokenizer
| Check | Status | Notes |
|-------|--------|-------|
| Yield calculation uses time-average | ☐ | |
| Cannot game yield with flash loan | ☐ | |

#### LVGStaking
| Check | Status | Notes |
|-------|--------|-------|
| Reward per token uses time-weight | ☐ | |
| Stake/unstake same block handled | ☐ | |

---

## 7. Upgrade Safety

### General Checks
| Check | Status | Notes |
|-------|--------|-------|
| Upgrade pattern identified | ☐ | Transparent/UUPS/Beacon |
| Implementation cannot be initialized | ☐ | `_disableInitializers()` |
| Storage layout documented | ☐ | |
| Upgrade timelock exists | ☐ | 48h+ recommended |

### Proxy Pattern Checks

#### If Using Transparent Proxy
| Check | Status | Notes |
|-------|--------|-------|
| ProxyAdmin separate from protocol admin | ☐ | |
| No selector clashes | ☐ | |
| Admin functions only callable by admin | ☐ | |

#### If Using UUPS
| Check | Status | Notes |
|-------|--------|-------|
| `_authorizeUpgrade` properly protected | ☐ | |
| Implementation has upgrade function | ☐ | |
| Cannot brick via bad upgrade | ☐ | |

### Storage Safety
| Check | Status | Notes |
|-------|--------|-------|
| Storage gaps in base contracts | ☐ | `uint256[50] __gap` |
| No storage collision on upgrade | ☐ | Use storage checker tools |
| Initializers cannot be re-called | ☐ | `initializer` modifier |
| State preserved on upgrade | ☐ | |

### Per-Contract Upgrade Status

| Contract | Upgradeable | Pattern | Timelock |
|----------|-------------|---------|----------|
| LVGToken | ☐ Yes / ☐ No | | |
| LVGStaking | ☐ Yes / ☐ No | | |
| LendingPoolV5 | ☐ Yes / ☐ No | | |
| LeveragedFarmV3 | ☐ Yes / ☐ No | | |
| YieldTokenizer | ☐ Yes / ☐ No | | |
| PerpVault | ☐ Yes / ☐ No | | |
| PositionManager | ☐ Yes / ☐ No | | |
| VotingEscrow | ☐ Yes / ☐ No | | |
| GaugeController | ☐ Yes / ☐ No | | |

---

## 8. Economic Attacks

### Price Manipulation
| Check | Status | Notes |
|-------|--------|-------|
| DEX pool liquidity sufficient | ☐ | Cost to move price 10%? |
| TWAP period appropriate | ☐ | 30min+ for large values |
| Multiple oracle sources | ☐ | Chainlink + DEX TWAP |
| Price impact limits | ☐ | Max slippage enforced |

### Sandwich Attack Protection
| Check | Status | Notes |
|-------|--------|-------|
| Slippage tolerance user-defined | ☐ | |
| Deadline parameter required | ☐ | |
| Private mempool option documented | ☐ | Flashbots, etc. |
| MEV-resistant design considered | ☐ | |

### Economic Exploits

#### Arbitrage Risks
| Check | Status | Notes |
|-------|--------|-------|
| Interest rate arbitrage checked | ☐ | Borrow cheap, lend expensive |
| Cross-pool arbitrage handled | ☐ | |
| Fee structure prevents drain | ☐ | |

#### Incentive Manipulation
| Check | Status | Notes |
|-------|--------|-------|
| Reward emission rate sane | ☐ | |
| Cannot game reward distribution | ☐ | |
| Boost mechanics abuse-resistant | ☐ | VotingEscrow boosts |

#### Liquidation MEV
| Check | Status | Notes |
|-------|--------|-------|
| Liquidation bonus not excessive | ☐ | Attracts MEV bots |
| Keeper network considered | ☐ | Chainlink Automation |
| Partial fills don't leave dust | ☐ | |

### Protocol-Specific Economic Checks

#### LeveragedFarmV3
| Check | Status | Notes |
|-------|--------|-------|
| Max leverage reasonable | ☐ | 10x max recommended |
| Funding rate caps exist | ☐ | |
| Position size limits | ☐ | Whale protection |

#### PerpVault
| Check | Status | Notes |
|-------|--------|-------|
| Open interest limits | ☐ | |
| Funding rate balanced | ☐ | Long vs short |
| Price band limits | ☐ | Max 15% from oracle |

---

## Summary Checklist

### Pre-Deployment
- [ ] All contracts verified on block explorer
- [ ] Multisig ownership configured
- [ ] Timelocks active
- [ ] Bug bounty program live
- [ ] Emergency procedures documented

### Critical Items (Must Pass)
- [ ] Reentrancy protection on all value functions
- [ ] Oracle staleness checks implemented
- [ ] Liquidation math verified
- [ ] Access control properly configured
- [ ] No unchecked overflow in critical paths

### High Priority
- [ ] Flash loan attack vectors mitigated
- [ ] Upgrade safety verified
- [ ] Economic attack resistance tested
- [ ] First depositor attack prevented

### Recommended
- [ ] Formal verification on core math
- [ ] Invariant testing completed
- [ ] Third-party audit scheduled
- [ ] Insurance coverage obtained

---

## Audit Trail

| Date | Auditor | Section | Status | Notes |
|------|---------|---------|--------|-------|
| 2026-02-10 | Nina | Initial Checklist | Created | Ready for review |
| | | | | |
| | | | | |

---

*Generated by Nina (Security Engineer) for LEVERAGED 2.0*  
*This checklist should be used in conjunction with manual code review and automated tooling (Slither, Mythril, Echidna)*
