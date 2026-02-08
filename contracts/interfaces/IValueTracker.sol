// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title IValueTracker
 * @notice Interface for tracking entry/exit values for fee calculation
 */
interface IValueTracker {
    
    // ============ Structs ============
    
    struct ValueRecord {
        uint256 entryPrice;         // Price at entry
        uint256 entryTimestamp;     // When position was opened
        uint256 depositValue;       // Value in USD at entry
    }
    
    // ============ Events ============
    
    event ValueRecorded(
        uint256 indexed positionId,
        address indexed asset,
        uint256 entryPrice,
        uint256 depositValue
    );
    
    event ValueIncreaseCalculated(
        uint256 indexed positionId,
        uint256 entryValue,
        uint256 exitValue,
        uint256 valueIncrease,
        uint256 platformFee
    );
    
    // ============ Functions ============
    
    /**
     * @notice Record entry value for a position
     * @param positionId The position ID
     * @param asset The asset
     * @param depositValue The deposit value in USD
     */
    function recordEntry(
        uint256 positionId,
        address asset,
        uint256 depositValue
    ) external;
    
    /**
     * @notice Calculate value increase and platform fee
     * @param positionId The position ID
     * @param currentPrice Current asset price
     * @return valueIncrease Total value increase
     * @return platformFee 25% fee for platform
     * @return userAmount Amount user receives
     */
    function calculateValueIncrease(
        uint256 positionId,
        uint256 currentPrice
    ) external view returns (
        uint256 valueIncrease,
        uint256 platformFee,
        uint256 userAmount
    );
    
    /**
     * @notice Get value record for a position
     * @param positionId The position ID
     * @return record The value record
     */
    function getValueRecord(uint256 positionId) external view returns (ValueRecord memory);
}
