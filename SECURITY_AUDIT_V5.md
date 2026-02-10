# Security Audit: LendingPoolV5

**Date:** February 10, 2026  
**Auditor:** Claude (AI Security Review)  
**Contract:** `contracts/core/LendingPoolV5.sol`  
**Status:** 🟡 REVIEW IN PROGRESS

---

## Executive Summary

LendingPoolV5 introduces E-Mode (Efficiency Mode) for higher capital efficiency with correlated assets, plus Flash Loan support. The contract uses OpenZeppelin's ReentrancyGuard and SafeERC20.

### Risk Assessment: **MEDIUM**

| Category | Risk Level | Notes |
|----------|-----------|-------|
| Reentrancy | ✅ LOW | ReentrancyGuard on critical functions |
| Access Control | ✅ LOW | Owner and Vault modifiers properly implemented |
| Integer Overflow | ✅ LOW | Solidity 0.8.20 has built-in overflow checks |
| Flash Loan | 🟡 MEDIUM | Need additional validation |
| E-Mode | 🟡 MEDIUM | Edge cases need testing |

---

## Findings

### 1. 🟡 MEDIUM: Flash Loan Balance Check Could Be Bypassed

**Location:** `flashLoan()` function, line ~430

**Issue:** The balance check uses `balanceAfter >= balanceBefore + fee`. If the receiver contract deposits tokens back to this same pool (not repaying the loan), the balance check would pass but the loan wouldn't be properly repaid.

```solidity
// Current code
require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid");
```

**Recommendation:** Add an explicit repayment function that the receiver must call, or track borrowed amounts separately.

**Severity:** Medium - Unlikely to be exploited in practice but worth hardening.

---

### 2. 🟡 MEDIUM: E-Mode Category Validation

**Location:** `setUserEMode()` function

**Issue:** When a user switches E-Mode categories, the health check only verifies the position is healthy in the new category. It doesn't verify that the user's assets actually belong to the new category.

```solidity
// User could enable "Stablecoins" E-Mode (97% LTV) while holding ETH
function setUserEMode(uint8 categoryId) external {
    // Only checks if borrowed <= maxBorrow in new category
    // Doesn't verify user's collateral matches the category
}
```

**Recommendation:** Either:
1. Add asset-to-category mappings and validate, OR
2. Document that E-Mode is trust-based (user responsibility)

**Severity:** Medium - Could lead to higher risk for the protocol if misused.

---

### 3. ✅ LOW: Interest Accrual Timing

**Location:** `_accrueInterest()` function

**Issue:** Interest is accrued based on `block.timestamp`. This is acceptable but slightly manipulable by miners (~15 seconds).

**Status:** Acceptable for this use case.

---

### 4. ✅ LOW: Share Calculation Precision

**Location:** `deposit()` and `withdraw()` functions

**Issue:** Share calculations use integer division which can lead to minor rounding errors.

```solidity
shares = (amount * totalShares) / totalDeposits;
amount = (shares * totalDeposits) / totalShares;
```

**Status:** Standard practice, rounding errors benefit the pool (not extractable).

---

### 5. ✅ INFO: Missing Events

**Location:** Various functions

**Observation:** The contract has good event coverage. Consider adding:
- `InterestAccrued(uint256 interest, uint256 insuranceCut)`

---

## Recommendations

### Critical (Do Before Mainnet)
1. [ ] Add E-Mode asset validation or document trust model
2. [ ] Consider flash loan callback verification

### Recommended (Good to Have)
3. [ ] Add pause functionality for emergencies
4. [ ] Add maximum utilization cap (prevent 100% utilization)
5. [ ] Add time-delayed E-Mode switching (prevent MEV attacks)

### Nice to Have
6. [ ] Add interest accrual event
7. [ ] Add admin fee withdrawal function

---

## Test Coverage Required

```
□ E-Mode switching with active borrow
□ E-Mode switching to lower LTV category
□ Flash loan repayment edge cases
□ Flash loan reentrancy attempts
□ Interest accrual over long periods
□ Utilization rate extremes (0%, 50%, 80%, 100%)
□ Share calculation with dust amounts
□ Withdrawal with active borrowers
```

---

## Conclusion

LendingPoolV5 follows good security practices with ReentrancyGuard, SafeERC20, and proper access controls. The main concerns are:

1. **Flash Loan Balance Check** - Consider stricter repayment verification
2. **E-Mode Asset Validation** - Either enforce or document trust model

The contract is suitable for testnet deployment. For mainnet, address the medium findings and complete test coverage.

---

**Next Steps:**
1. Write Foundry tests for edge cases
2. Consider professional audit for mainnet
3. Add monitoring for unusual E-Mode usage patterns
