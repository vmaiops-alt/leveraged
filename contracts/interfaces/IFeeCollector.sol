// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title IFeeCollector
 * @notice Interface for fee collection and distribution
 */
interface IFeeCollector {
    
    // ============ Events ============
    
    event FeesCollected(address indexed token, uint256 amount, string feeType);
    event FeesDistributed(uint256 toTreasury, uint256 toInsurance, uint256 toStakers);
    event TreasurySet(address indexed treasury);
    event InsuranceFundSet(address indexed insuranceFund);
    event StakingContractSet(address indexed stakingContract);
    
    // ============ Functions ============
    
    /**
     * @notice Collect fees from vault
     * @param token The token address
     * @param amount Amount of fees
     * @param feeType Type of fee (valueIncrease, performance, entry, liquidation)
     */
    function collectFees(address token, uint256 amount, string calldata feeType) external;
    
    /**
     * @notice Distribute collected fees
     */
    function distributeFees() external;
    
    /**
     * @notice Get pending fees for distribution
     * @param token The token address
     * @return pending Pending fee amount
     */
    function getPendingFees(address token) external view returns (uint256);
    
    /**
     * @notice Get fee distribution ratios
     * @return treasuryRatio Treasury ratio in BPS
     * @return insuranceRatio Insurance fund ratio in BPS
     * @return stakerRatio Staker ratio in BPS
     */
    function getFeeRatios() external view returns (
        uint256 treasuryRatio,
        uint256 insuranceRatio,
        uint256 stakerRatio
    );
}
