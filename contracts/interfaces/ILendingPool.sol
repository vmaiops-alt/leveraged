// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title ILendingPool
 * @notice Interface for the internal lending pool
 */
interface ILendingPool {
    
    // ============ Events ============
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event Borrowed(address indexed borrower, uint256 amount);
    event Repaid(address indexed borrower, uint256 amount, uint256 interest);
    
    // ============ Functions ============
    
    /**
     * @notice Deposit stablecoins to earn interest
     * @param amount Amount to deposit
     * @return shares LP shares received
     */
    function deposit(uint256 amount) external returns (uint256 shares);
    
    /**
     * @notice Withdraw stablecoins
     * @param shares LP shares to burn
     * @return amount Stablecoins received
     */
    function withdraw(uint256 shares) external returns (uint256 amount);
    
    /**
     * @notice Borrow stablecoins (only callable by Vault)
     * @param amount Amount to borrow
     * @param borrower The borrower (position owner)
     */
    function borrow(uint256 amount, address borrower) external;
    
    /**
     * @notice Repay borrowed amount (only callable by Vault)
     * @param amount Amount to repay
     * @param borrower The borrower
     * @return interest Interest paid
     */
    function repay(uint256 amount, address borrower) external returns (uint256 interest);
    
    /**
     * @notice Get current borrow rate
     * @return rate Annual borrow rate in basis points
     */
    function getBorrowRate() external view returns (uint256);
    
    /**
     * @notice Get current supply rate
     * @return rate Annual supply rate in basis points
     */
    function getSupplyRate() external view returns (uint256);
    
    /**
     * @notice Get utilization rate
     * @return rate Utilization rate in basis points (10000 = 100%)
     */
    function getUtilizationRate() external view returns (uint256);
    
    /**
     * @notice Get total available liquidity
     * @return liquidity Available to borrow
     */
    function getAvailableLiquidity() external view returns (uint256);
    
    /**
     * @notice Get user's borrowed amount
     * @param user The user address
     * @return borrowed Amount borrowed including interest
     */
    function getBorrowedAmount(address user) external view returns (uint256);
}
