// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/**
 * @title MaturityMath
 * @notice Mathematical utilities for yield tokenization calculations
 * @dev Handles time-based yield calculations, discounting, and PT/YT pricing
 */
library MaturityMath {
    
    uint256 public constant PRECISION = 1e18;
    uint256 public constant YEAR = 365 days;
    uint256 public constant BASIS_POINTS = 10000;
    
    /**
     * @notice Calculate PT price based on implied yield and time to maturity
     * @param impliedRate Annual implied yield rate (18 decimals, e.g., 0.05e18 = 5%)
     * @param timeToMaturity Seconds until maturity
     * @return ptPrice PT price in underlying terms (18 decimals)
     * @dev PT Price = 1 / (1 + rate * timeToMaturity / YEAR)
     */
    function calculatePtPrice(
        uint256 impliedRate,
        uint256 timeToMaturity
    ) internal pure returns (uint256 ptPrice) {
        if (timeToMaturity == 0) return PRECISION;
        
        // rate * timeToMaturity / YEAR
        uint256 discountFactor = (impliedRate * timeToMaturity) / YEAR;
        
        // 1 / (1 + discountFactor)
        ptPrice = (PRECISION * PRECISION) / (PRECISION + discountFactor);
    }
    
    /**
     * @notice Calculate YT price based on implied yield and time to maturity
     * @param impliedRate Annual implied yield rate (18 decimals)
     * @param timeToMaturity Seconds until maturity
     * @return ytPrice YT price in underlying terms (18 decimals)
     * @dev YT Price = 1 - PT Price = rate * timeToMaturity / (1 + rate * timeToMaturity)
     */
    function calculateYtPrice(
        uint256 impliedRate,
        uint256 timeToMaturity
    ) internal pure returns (uint256 ytPrice) {
        if (timeToMaturity == 0) return 0;
        
        uint256 ptPrice = calculatePtPrice(impliedRate, timeToMaturity);
        ytPrice = PRECISION - ptPrice;
    }
    
    /**
     * @notice Calculate implied yield from PT price and time to maturity
     * @param ptPrice PT price in underlying terms (18 decimals)
     * @param timeToMaturity Seconds until maturity
     * @return impliedRate Annual implied yield rate (18 decimals)
     * @dev Rate = (1/ptPrice - 1) * YEAR / timeToMaturity
     */
    function calculateImpliedRate(
        uint256 ptPrice,
        uint256 timeToMaturity
    ) internal pure returns (uint256 impliedRate) {
        if (timeToMaturity == 0 || ptPrice >= PRECISION) return 0;
        if (ptPrice == 0) return type(uint256).max; // Infinite rate
        
        // (1/ptPrice - 1) = (PRECISION - ptPrice) / ptPrice
        uint256 discount = ((PRECISION - ptPrice) * PRECISION) / ptPrice;
        
        // Annualize: discount * YEAR / timeToMaturity
        impliedRate = (discount * YEAR) / timeToMaturity;
    }
    
    /**
     * @notice Calculate present value of future yield
     * @param fv Expected yield at maturity (18 decimals)
     * @param discountRate Discount rate (18 decimals)
     * @param timeToMaturity Seconds until maturity
     * @return presentValue Discounted present value (18 decimals)
     */
    function presentValue(
        uint256 fv,
        uint256 discountRate,
        uint256 timeToMaturity
    ) internal pure returns (uint256) {
        if (timeToMaturity == 0) return fv;
        
        uint256 discountFactor = (discountRate * timeToMaturity) / YEAR;
        return (fv * PRECISION) / (PRECISION + discountFactor);
    }
    
    /**
     * @notice Calculate future value of present amount
     * @param presentAmount Current amount (18 decimals)
     * @param rate Annual rate (18 decimals)
     * @param timeToMaturity Seconds until maturity
     * @return futureValue Amount at maturity (18 decimals)
     */
    function futureValue(
        uint256 presentAmount,
        uint256 rate,
        uint256 timeToMaturity
    ) internal pure returns (uint256) {
        if (timeToMaturity == 0) return presentAmount;
        
        uint256 growthFactor = (rate * timeToMaturity) / YEAR;
        return (presentAmount * (PRECISION + growthFactor)) / PRECISION;
    }
    
    /**
     * @notice Calculate YT leverage (exposure to yield per unit invested)
     * @param ytPrice YT price in underlying terms (18 decimals)
     * @param timeToMaturity Seconds until maturity
     * @return leverage YT leverage multiple (18 decimals)
     * @dev Leverage = 1 / ytPrice adjusted for time
     */
    function calculateYtLeverage(
        uint256 ytPrice,
        uint256 timeToMaturity
    ) internal pure returns (uint256 leverage) {
        if (ytPrice == 0 || timeToMaturity == 0) return 0;
        
        // Raw leverage = 1 / ytPrice
        uint256 rawLeverage = (PRECISION * PRECISION) / ytPrice;
        
        // Adjust for annualization
        leverage = (rawLeverage * YEAR) / timeToMaturity;
    }
    
    /**
     * @notice Calculate break-even yield for YT holder
     * @param ytPrice YT price paid (18 decimals)
     * @param timeToMaturity Seconds until maturity
     * @return breakEvenYield Minimum APY needed to break even (18 decimals)
     */
    function calculateBreakEvenYield(
        uint256 ytPrice,
        uint256 timeToMaturity
    ) internal pure returns (uint256 breakEvenYield) {
        if (timeToMaturity == 0) return type(uint256).max;
        
        // Need yield such that: yield * timeToMaturity / YEAR >= ytPrice
        // breakEvenYield = ytPrice * YEAR / timeToMaturity
        breakEvenYield = (ytPrice * YEAR) / timeToMaturity;
    }
    
    /**
     * @notice Calculate accrued yield for a position
     * @param principal Original principal amount
     * @param startIndex Yield index at deposit
     * @param currentIndex Current yield index
     * @return accruedYield Yield earned (same decimals as principal)
     */
    function calculateAccruedYield(
        uint256 principal,
        uint256 startIndex,
        uint256 currentIndex
    ) internal pure returns (uint256 accruedYield) {
        if (currentIndex <= startIndex) return 0;
        
        // accruedYield = principal * (currentIndex - startIndex) / startIndex
        accruedYield = (principal * (currentIndex - startIndex)) / startIndex;
    }
    
    /**
     * @notice Calculate time-weighted average rate
     * @param rate1 First rate (18 decimals)
     * @param time1 Time period for first rate
     * @param rate2 Second rate (18 decimals)
     * @param time2 Time period for second rate
     * @return avgRate Time-weighted average rate (18 decimals)
     */
    function timeWeightedAverage(
        uint256 rate1,
        uint256 time1,
        uint256 rate2,
        uint256 time2
    ) internal pure returns (uint256 avgRate) {
        uint256 totalTime = time1 + time2;
        if (totalTime == 0) return 0;
        
        avgRate = ((rate1 * time1) + (rate2 * time2)) / totalTime;
    }
    
    /**
     * @notice Check if position is near maturity (within threshold)
     * @param maturity Maturity timestamp
     * @param threshold Time threshold in seconds
     * @return isNear True if within threshold of maturity
     */
    function isNearMaturity(
        uint256 maturity,
        uint256 threshold
    ) internal view returns (bool isNear) {
        if (block.timestamp >= maturity) return true;
        return (maturity - block.timestamp) <= threshold;
    }
    
    /**
     * @notice Safe percentage calculation
     * @param amount Base amount
     * @param bps Basis points (10000 = 100%)
     * @return result Amount * bps / 10000
     */
    function bpsOf(uint256 amount, uint256 bps) internal pure returns (uint256 result) {
        result = (amount * bps) / BASIS_POINTS;
    }
    
    /**
     * @notice Calculate compound interest
     * @param principal Initial amount
     * @param rate Annual rate (18 decimals)
     * @param periods Number of compounding periods
     * @param periodLength Length of each period in seconds
     * @return amount Compounded amount
     */
    function compoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 periods,
        uint256 periodLength
    ) internal pure returns (uint256 amount) {
        amount = principal;
        uint256 periodRate = (rate * periodLength) / YEAR;
        
        for (uint256 i = 0; i < periods && i < 365; i++) {
            amount = (amount * (PRECISION + periodRate)) / PRECISION;
        }
    }
}
