// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title IStrategy
 * @notice Base interface for yield strategies
 */
interface IStrategy {
    
    /**
     * @notice Deposit funds into the strategy
     * @param amount Amount to deposit
     * @return shares Strategy shares received
     */
    function deposit(uint256 amount) external returns (uint256 shares);
    
    /**
     * @notice Withdraw funds from the strategy
     * @param shares Shares to withdraw
     * @return amount Amount received
     */
    function withdraw(uint256 shares) external returns (uint256 amount);
    
    /**
     * @notice Harvest rewards and reinvest
     * @return harvested Amount of rewards harvested
     */
    function harvest() external returns (uint256 harvested);
    
    /**
     * @notice Get current APY
     * @return apy Annual percentage yield in BPS
     */
    function getAPY() external view returns (uint256 apy);
    
    /**
     * @notice Get total value locked in strategy
     * @return tvl Total value locked
     */
    function getTVL() external view returns (uint256 tvl);
    
    /**
     * @notice Get user's deposited value
     * @param user User address
     * @return value User's value in the strategy
     */
    function getUserValue(address user) external view returns (uint256 value);
    
    /**
     * @notice Get the underlying asset
     * @return asset Asset address
     */
    function asset() external view returns (address);
    
    /**
     * @notice Get pending rewards
     * @return pending Pending reward amount
     */
    function pendingRewards() external view returns (uint256 pending);
}
