# LEVERAGED 2.0 - E2E Test Plan

**Version:** 1.0  
**Last Updated:** 2026-02-10  
**Author:** Dev (QA Engineer)

---

## 📋 Contract Addresses (BSC Testnet)

| Contract | Address |
|----------|---------|
| LVGToken | `0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1` |
| LVGStaking | `0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F` |
| LendingPoolV5 | `0x088c08057D51B9C76B06102B95EF0555A1c44507` |
| LeveragedFarmV3 | `0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05` |
| VotingEscrow | `0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D` |
| GaugeController | `0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5` |

---

## 🔐 Prerequisites

- [ ] MetaMask installed with BSC Testnet configured
- [ ] Test wallet with tBNB for gas
- [ ] Test LVG tokens (mint from faucet or get from team)
- [ ] Test USDT tokens
- [ ] Access to dApp frontend at staging URL

---

## 1️⃣ STAKING FLOW

### TC-STK-001: Connect Wallet

**Description:** User connects MetaMask wallet to the dApp

**Preconditions:**
- MetaMask installed
- BSC Testnet configured
- Wallet has tBNB for gas

**Steps:**
1. Navigate to LEVERAGED dApp
2. Click "Connect Wallet" button
3. Select MetaMask from wallet options
4. Approve connection in MetaMask popup
5. Verify wallet address displayed in header

**Expected Results:**
- ✅ Wallet address shown in header (truncated format: 0x1234...5678)
- ✅ Network indicator shows BSC Testnet
- ✅ User balances loaded and displayed
- ✅ Staking page accessible

**Contract Interaction:** None (frontend only)

---

### TC-STK-002: Approve LVG for Staking

**Description:** User approves LVGStaking contract to spend LVG tokens

**Preconditions:**
- Wallet connected (TC-STK-001 passed)
- Wallet has LVG balance > 0

**Steps:**
1. Navigate to Staking page
2. Enter amount to stake (e.g., 100 LVG)
3. Click "Approve" button
4. Confirm transaction in MetaMask
5. Wait for transaction confirmation

**Expected Results:**
- ✅ Approve button enabled when amount entered
- ✅ MetaMask popup shows approval tx for LVGStaking spender
- ✅ Transaction confirms on-chain
- ✅ "Approve" button changes to "Stake" button
- ✅ Allowance updated: `allowance >= stake amount`

**Contract Interaction:**
```solidity
LVGToken.approve(LVGStaking, amount)
```

**Verification Query:**
```solidity
LVGToken.allowance(userAddress, LVGStaking) >= amount
```

---

### TC-STK-003: Stake LVG Tokens

**Description:** User stakes approved LVG tokens

**Preconditions:**
- TC-STK-002 passed (approval given)
- Sufficient LVG balance

**Steps:**
1. Enter stake amount (e.g., 100 LVG)
2. Click "Stake" button
3. Confirm transaction in MetaMask
4. Wait for transaction confirmation

**Expected Results:**
- ✅ Transaction confirms successfully
- ✅ LVG balance decreases by stake amount
- ✅ Staked balance increases by stake amount
- ✅ UI shows updated staked position
- ✅ Event `Staked(user, amount)` emitted

**Contract Interaction:**
```solidity
LVGStaking.stake(amount)
```

**Verification Query:**
```solidity
LVGStaking.stakedBalance(userAddress) == previousStaked + amount
LVGToken.balanceOf(userAddress) == previousBalance - amount
```

---

### TC-STK-004: Check Staked Balance

**Description:** Verify staked balance displays correctly

**Preconditions:**
- TC-STK-003 passed (tokens staked)

**Steps:**
1. Navigate to Staking page
2. View staked balance display
3. Compare with on-chain query

**Expected Results:**
- ✅ UI shows correct staked amount
- ✅ Rewards accruing displayed (if applicable)
- ✅ APY/APR displayed correctly
- ✅ Balance matches `stakedBalance(user)` contract call

**Contract Interaction:**
```solidity
LVGStaking.stakedBalance(userAddress)
LVGStaking.earned(userAddress)
```

---

### TC-STK-005: Unstake LVG Tokens

**Description:** User unstakes their LVG tokens

**Preconditions:**
- Staked balance > 0

**Steps:**
1. Navigate to Staking page
2. Click "Unstake" or enter amount to unstake
3. Confirm unstake amount
4. Confirm transaction in MetaMask
5. Wait for transaction confirmation

**Expected Results:**
- ✅ Transaction confirms successfully
- ✅ Staked balance decreases
- ✅ LVG wallet balance increases
- ✅ Pending rewards claimed (if auto-claim)
- ✅ Event `Unstaked(user, amount)` emitted

**Contract Interaction:**
```solidity
LVGStaking.unstake(amount)
// or LVGStaking.withdraw(amount)
```

---

## 2️⃣ LENDING FLOW

### TC-LND-001: Deposit USDT to Lending Pool

**Description:** User deposits USDT as collateral/supply

**Preconditions:**
- Wallet connected
- USDT balance > 0
- USDT approved for LendingPoolV5

**Steps:**
1. Navigate to Lending page
2. Select USDT from asset list
3. Click "Supply" or "Deposit"
4. Enter deposit amount (e.g., 1000 USDT)
5. If not approved, click "Approve USDT"
6. Confirm approval in MetaMask
7. Click "Deposit"
8. Confirm transaction in MetaMask
9. Wait for confirmation

**Expected Results:**
- ✅ Approval tx succeeds (if needed)
- ✅ Deposit tx confirms
- ✅ USDT balance decreases
- ✅ Supply balance shows deposited amount
- ✅ Collateral value updated
- ✅ Event `Deposit(user, asset, amount)` emitted

**Contract Interaction:**
```solidity
USDT.approve(LendingPoolV5, amount)
LendingPoolV5.deposit(USDT_address, amount, userAddress, 0)
```

---

### TC-LND-002: Check Supply Balance

**Description:** Verify supplied/deposited balance

**Preconditions:**
- TC-LND-001 passed

**Steps:**
1. View Lending dashboard
2. Check "Your Supplies" section
3. Verify USDT supply amount
4. Check accrued interest

**Expected Results:**
- ✅ Supply balance matches deposited amount
- ✅ Interest accruing visible
- ✅ Collateral factor displayed
- ✅ Health factor calculated (if borrowing)

**Contract Interaction:**
```solidity
LendingPoolV5.getUserAccountData(userAddress)
aUSDT.balanceOf(userAddress) // if using aTokens
```

---

### TC-LND-003: Borrow Against Collateral

**Description:** User borrows asset using deposited collateral

**Preconditions:**
- TC-LND-001 passed (collateral deposited)
- Sufficient collateral for desired borrow

**Steps:**
1. Navigate to Lending page
2. Select asset to borrow (e.g., BNB or another token)
3. Enter borrow amount
4. Review health factor preview
5. Click "Borrow"
6. Confirm transaction in MetaMask
7. Wait for confirmation

**Expected Results:**
- ✅ Borrow tx confirms
- ✅ Borrowed asset received in wallet
- ✅ Debt balance shows borrowed amount
- ✅ Health factor decreased (but > 1.0)
- ✅ Event `Borrow(user, asset, amount, borrowRate)` emitted

**Contract Interaction:**
```solidity
LendingPoolV5.borrow(asset_address, amount, interestRateMode, 0, userAddress)
```

**Risk Check:**
- Health Factor must remain > 1.0
- Borrow amount <= available liquidity

---

### TC-LND-004: Repay Borrowed Amount

**Description:** User repays part or all of borrowed amount

**Preconditions:**
- Active borrow position
- Sufficient balance to repay

**Steps:**
1. Navigate to Lending page
2. Find borrowed position
3. Click "Repay"
4. Enter repay amount (or select "Max")
5. Approve asset if needed
6. Confirm transaction
7. Wait for confirmation

**Expected Results:**
- ✅ Repay tx confirms
- ✅ Debt balance decreases
- ✅ Health factor improves
- ✅ Interest paid included in repay
- ✅ Event `Repay(user, asset, amount)` emitted

**Contract Interaction:**
```solidity
asset.approve(LendingPoolV5, amount)
LendingPoolV5.repay(asset_address, amount, interestRateMode, userAddress)
```

---

### TC-LND-005: Withdraw from Lending Pool

**Description:** User withdraws supplied collateral

**Preconditions:**
- Supply balance > 0
- Withdrawal won't cause liquidation (health factor check)

**Steps:**
1. Navigate to Lending page
2. Find supplied position
3. Click "Withdraw"
4. Enter withdraw amount
5. Review health factor impact (if borrowing)
6. Confirm transaction
7. Wait for confirmation

**Expected Results:**
- ✅ Withdraw tx confirms
- ✅ Supply balance decreases
- ✅ Asset returned to wallet
- ✅ Health factor updated (if borrowing)
- ✅ Event `Withdraw(user, asset, amount)` emitted

**Contract Interaction:**
```solidity
LendingPoolV5.withdraw(asset_address, amount, userAddress)
```

---

## 3️⃣ FARM FLOW (Leveraged Positions)

### TC-FRM-001: Open Leveraged Position

**Description:** User opens a leveraged farming position

**Preconditions:**
- Wallet connected
- Collateral deposited in LendingPool (or direct deposit)
- Sufficient balance for margin

**Steps:**
1. Navigate to Farm page
2. Select farm/pool (e.g., BNB-USDT LP)
3. Select leverage amount (e.g., 3x)
4. Enter collateral/margin amount
5. Review position details:
   - Entry price
   - Liquidation price
   - Estimated APY
   - Fees
6. Click "Open Position"
7. Approve tokens if needed
8. Confirm transaction
9. Wait for confirmation

**Expected Results:**
- ✅ Position creation tx confirms
- ✅ Position ID assigned
- ✅ Collateral locked
- ✅ Leveraged position visible in "Your Positions"
- ✅ Position details match input parameters
- ✅ Event `PositionOpened(positionId, user, collateral, leverage)` emitted

**Contract Interaction:**
```solidity
// Approve collateral
collateralToken.approve(LeveragedFarmV3, amount)

// Open position
LeveragedFarmV3.openPosition(
    poolId,
    collateralAmount,
    leverage,
    minLpAmount
)
```

---

### TC-FRM-002: Check Position Details

**Description:** View and verify open position details

**Preconditions:**
- TC-FRM-001 passed (position open)

**Steps:**
1. Navigate to Farm page
2. View "Your Positions" section
3. Click on position to expand details
4. Verify all displayed values

**Expected Results:**
- ✅ Position ID displayed
- ✅ Collateral amount correct
- ✅ Leverage multiplier correct
- ✅ Current value displayed
- ✅ PnL (Profit/Loss) calculated
- ✅ Liquidation price shown
- ✅ Health status indicator
- ✅ Accrued rewards visible

**Contract Interaction:**
```solidity
LeveragedFarmV3.getPosition(positionId)
LeveragedFarmV3.getPositionHealth(positionId)
LeveragedFarmV3.pendingRewards(positionId)
```

---

### TC-FRM-003: Close Leveraged Position

**Description:** User closes their leveraged position

**Preconditions:**
- Open position exists
- Position not liquidated

**Steps:**
1. Navigate to Farm page
2. Find position in "Your Positions"
3. Click "Close Position"
4. Review closing details:
   - Current value
   - Estimated return
   - Fees
   - PnL
5. Confirm close
6. Confirm transaction in MetaMask
7. Wait for confirmation

**Expected Results:**
- ✅ Close tx confirms
- ✅ Position removed from active list
- ✅ Collateral + PnL returned to wallet
- ✅ Borrowed amount repaid automatically
- ✅ Rewards claimed
- ✅ Event `PositionClosed(positionId, user, returnAmount)` emitted

**Contract Interaction:**
```solidity
LeveragedFarmV3.closePosition(positionId, minReturnAmount)
```

---

## 4️⃣ GOVERNANCE FLOW

### TC-GOV-001: Lock LVG for veLVG

**Description:** User locks LVG tokens to receive vote-escrowed LVG (veLVG)

**Preconditions:**
- Wallet connected
- LVG balance > 0
- LVG approved for VotingEscrow

**Steps:**
1. Navigate to Governance page
2. Find "Lock LVG" section
3. Enter LVG amount to lock
4. Select lock duration (e.g., 1 year, 2 years, 4 years)
5. Review veLVG amount to receive
6. Approve LVG if needed
7. Click "Lock"
8. Confirm transaction
9. Wait for confirmation

**Expected Results:**
- ✅ Lock tx confirms
- ✅ LVG transferred to VotingEscrow
- ✅ veLVG balance shows received amount
- ✅ Lock expiry date displayed
- ✅ Voting power assigned
- ✅ Event `Deposit(provider, value, locktime, type)` emitted

**Contract Interaction:**
```solidity
LVGToken.approve(VotingEscrow, amount)
VotingEscrow.create_lock(amount, unlock_time)
```

**veLVG Calculation:**
- veLVG = LVG × (lock_time_remaining / max_lock_time)
- Max lock = 4 years = maximum veLVG

---

### TC-GOV-002: Vote on Gauge

**Description:** User votes to allocate rewards to a gauge/pool

**Preconditions:**
- TC-GOV-001 passed (has veLVG)
- Voting period active (if applicable)

**Steps:**
1. Navigate to Governance > Gauges page
2. View available gauges/pools
3. Select gauge to vote for
4. Enter vote weight (% of voting power)
5. Click "Vote"
6. Confirm transaction
7. Wait for confirmation

**Expected Results:**
- ✅ Vote tx confirms
- ✅ Vote recorded on-chain
- ✅ Gauge weight updated
- ✅ User's vote allocation shown
- ✅ Remaining voting power updated
- ✅ Event `VoteForGauge(user, gauge_addr, weight)` emitted

**Contract Interaction:**
```solidity
GaugeController.vote_for_gauge_weights(gauge_address, weight)
```

**Notes:**
- Vote weight is in basis points (10000 = 100%)
- Votes can be changed once per 10-day period (typical)
- Votes decay as veLVG decays

---

### TC-GOV-003: Check Voting Power

**Description:** Verify current voting power and lock details

**Preconditions:**
- veLVG lock exists

**Steps:**
1. Navigate to Governance page
2. View voting power display
3. Check lock expiry date
4. View vote allocations

**Expected Results:**
- ✅ Current veLVG balance displayed
- ✅ Lock expiry timestamp shown
- ✅ Locked LVG amount visible
- ✅ Voting power % relative to total
- ✅ Active vote allocations listed
- ✅ Decay rate visible (power decreasing over time)

**Contract Interaction:**
```solidity
VotingEscrow.balanceOf(userAddress)
VotingEscrow.locked(userAddress) // returns (amount, end)
VotingEscrow.totalSupply() // total veLVG
GaugeController.vote_user_slopes(userAddress, gaugeAddress)
```

---

## 📊 Test Summary Matrix

| Flow | Test ID | Priority | Status |
|------|---------|----------|--------|
| **Staking** | TC-STK-001 | High | ⬜ |
| | TC-STK-002 | High | ⬜ |
| | TC-STK-003 | High | ⬜ |
| | TC-STK-004 | Medium | ⬜ |
| | TC-STK-005 | High | ⬜ |
| **Lending** | TC-LND-001 | High | ⬜ |
| | TC-LND-002 | Medium | ⬜ |
| | TC-LND-003 | High | ⬜ |
| | TC-LND-004 | High | ⬜ |
| | TC-LND-005 | High | ⬜ |
| **Farm** | TC-FRM-001 | Critical | ⬜ |
| | TC-FRM-002 | Medium | ⬜ |
| | TC-FRM-003 | Critical | ⬜ |
| **Governance** | TC-GOV-001 | High | ⬜ |
| | TC-GOV-002 | High | ⬜ |
| | TC-GOV-003 | Medium | ⬜ |

**Legend:**
- ⬜ Not Started
- 🔄 In Progress
- ✅ Passed
- ❌ Failed
- ⏭️ Skipped

---

## 🔧 Testing Tools

### Recommended Setup
1. **MetaMask** - Wallet connection
2. **BSCScan (Testnet)** - Transaction verification
3. **Hardhat Console** - Direct contract queries
4. **Tenderly** - Transaction simulation & debugging

### Useful Contract Queries (Hardhat Console)

```javascript
// Get user's staked balance
const staking = await ethers.getContractAt("LVGStaking", "0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F");
await staking.stakedBalance(userAddress);

// Get user's lending position
const lending = await ethers.getContractAt("LendingPoolV5", "0x088c08057D51B9C76B06102B95EF0555A1c44507");
await lending.getUserAccountData(userAddress);

// Get user's veLVG balance
const ve = await ethers.getContractAt("VotingEscrow", "0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D");
await ve.balanceOf(userAddress);

// Get leveraged position
const farm = await ethers.getContractAt("LeveragedFarmV3", "0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05");
await farm.getPosition(positionId);
```

---

## 🚨 Edge Cases to Test

### Staking
- [ ] Stake 0 amount (should revert)
- [ ] Stake more than balance (should revert)
- [ ] Unstake more than staked (should revert)
- [ ] Double approve (should work)

### Lending
- [ ] Deposit 0 (should revert)
- [ ] Borrow exceeding collateral factor (should revert)
- [ ] Withdraw causing liquidation (should revert)
- [ ] Repay more than debt (should cap at debt)

### Farm
- [ ] Open position with 0 collateral (should revert)
- [ ] Leverage above max allowed (should revert)
- [ ] Close non-existent position (should revert)
- [ ] Close already closed position (should revert)

### Governance
- [ ] Lock 0 LVG (should revert)
- [ ] Lock for < minimum time (should revert)
- [ ] Vote with 0 veLVG (should revert)
- [ ] Vote > 100% weight (should revert)
- [ ] Extend lock time
- [ ] Increase lock amount

---

## 📝 Bug Report Template

```markdown
**Bug ID:** BUG-XXX
**Test Case:** TC-XXX-XXX
**Severity:** Critical/High/Medium/Low
**Status:** Open/In Progress/Fixed/Verified

**Description:**
[Clear description of the issue]

**Steps to Reproduce:**
1. Step 1
2. Step 2
3. Step 3

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Transaction Hash:** 0x...
**Screenshot/Video:** [Link]

**Environment:**
- Browser: 
- Wallet: MetaMask v...
- Network: BSC Testnet
```

---

## ✅ Sign-Off Checklist

- [ ] All Critical tests passed
- [ ] All High priority tests passed
- [ ] Medium tests reviewed (failures documented)
- [ ] Edge cases tested
- [ ] No Critical/High bugs open
- [ ] Performance acceptable
- [ ] Security review complete
- [ ] Ready for mainnet deployment

**QA Sign-Off:** _________________ Date: _________

**Dev Sign-Off:** _________________ Date: _________

**PM Sign-Off:** _________________ Date: _________
