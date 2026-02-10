// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../interfaces/ILendingPool.sol";

/**
 * @title LendingPool
 * @notice Internal lending pool for providing leverage
 * @dev Users deposit stablecoins to earn interest, vault borrows for leverage
 */
contract LendingPool is ILendingPool {
    
    // ============ Constants ============
    
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    // Interest rate model parameters (in BPS)
    uint256 public constant BASE_RATE = 200;           // 2% base rate
    uint256 public constant RATE_SLOPE_1 = 400;        // 4% slope below optimal
    uint256 public constant RATE_SLOPE_2 = 7500;       // 75% slope above optimal  
    uint256 public constant OPTIMAL_UTILIZATION = 8000; // 80% optimal utilization
    
    // ============ State ============
    
    address public owner;
    address public vault;
    address public stablecoin;  // USDT/USDC address
    
    uint256 public totalDeposits;
    uint256 public totalBorrowed;
    uint256 public totalShares;
    
    mapping(address => uint256) public userShares;      // Depositor shares
    mapping(address => uint256) public borrowedAmount;  // Borrowed by position
    mapping(address => uint256) public borrowTimestamp; // When borrowed
    
    // ============ Events ============
    
    event VaultSet(address indexed vault);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVault() {
        require(msg.sender == vault, "Not vault");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _stablecoin) {
        owner = msg.sender;
        stablecoin = _stablecoin;
    }
    
    // ============ Admin Functions ============
    
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        vault = _vault;
        emit VaultSet(_vault);
    }
    
    // ============ Depositor Functions ============
    
    /**
     * @notice Deposit stablecoins to earn interest
     * @param amount Amount to deposit
     * @return shares LP shares received
     */
    function deposit(uint256 amount) external override returns (uint256 shares) {
        require(amount > 0, "Zero amount");
        
        // Transfer stablecoins from user
        _transferIn(msg.sender, amount);
        
        // Calculate shares
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalDeposits;
        }
        
        // Update state
        totalDeposits += amount;
        totalShares += shares;
        userShares[msg.sender] += shares;
        
        emit Deposited(msg.sender, amount, shares);
    }
    
    /**
     * @notice Withdraw stablecoins
     * @param shares LP shares to burn
     * @return amount Stablecoins received
     */
    function withdraw(uint256 shares) external override returns (uint256 amount) {
        require(shares > 0, "Zero shares");
        require(userShares[msg.sender] >= shares, "Insufficient shares");
        
        // Calculate amount
        amount = (shares * totalDeposits) / totalShares;
        
        // Check liquidity
        require(amount <= getAvailableLiquidity(), "Insufficient liquidity");
        
        // Update state
        totalDeposits -= amount;
        totalShares -= shares;
        userShares[msg.sender] -= shares;
        
        // Transfer stablecoins to user
        _transferOut(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, shares);
    }
    
    // ============ Vault Functions ============
    
    /**
     * @notice Borrow stablecoins (only callable by Vault)
     * @param amount Amount to borrow
     * @param borrower The borrower (position owner)
     */
    function borrow(uint256 amount, address borrower) external override onlyVault {
        require(amount > 0, "Zero amount");
        require(amount <= getAvailableLiquidity(), "Insufficient liquidity");
        
        // Accrue interest for existing borrow
        if (borrowedAmount[borrower] > 0) {
            borrowedAmount[borrower] = getBorrowedAmount(borrower);
        }
        
        // Update state
        borrowedAmount[borrower] += amount;
        borrowTimestamp[borrower] = block.timestamp;
        totalBorrowed += amount;
        
        // Transfer to vault
        _transferOut(vault, amount);
        
        emit Borrowed(borrower, amount);
    }
    
    /**
     * @notice Repay borrowed amount (only callable by Vault)
     * @param amount Amount to repay
     * @param borrower The borrower
     * @return interest Interest paid
     */
    function repay(uint256 amount, address borrower) external override onlyVault returns (uint256 interest) {
        uint256 totalOwed = getBorrowedAmount(borrower);
        require(totalOwed > 0, "Nothing to repay");
        
        // Calculate interest
        uint256 principal = borrowedAmount[borrower];
        interest = totalOwed > principal ? totalOwed - principal : 0;
        
        // Determine repay amount
        uint256 repayAmount = amount > totalOwed ? totalOwed : amount;
        
        // Transfer from vault
        _transferIn(vault, repayAmount);
        
        // Update state
        if (repayAmount >= totalOwed) {
            // Full repayment
            totalBorrowed -= principal;
            borrowedAmount[borrower] = 0;
            borrowTimestamp[borrower] = 0;
        } else {
            // Partial repayment
            uint256 principalRepaid = repayAmount > interest ? repayAmount - interest : 0;
            if (principalRepaid > 0) {
                totalBorrowed -= principalRepaid;
                borrowedAmount[borrower] = principal - principalRepaid;
            }
            borrowTimestamp[borrower] = block.timestamp;
        }
        
        // Interest goes to depositors (increases totalDeposits)
        totalDeposits += interest;
        
        emit Repaid(borrower, repayAmount, interest);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get current borrow rate
     * @return rate Annual borrow rate in basis points
     */
    function getBorrowRate() public view override returns (uint256) {
        uint256 utilization = getUtilizationRate();
        
        if (utilization <= OPTIMAL_UTILIZATION) {
            return BASE_RATE + (utilization * RATE_SLOPE_1) / OPTIMAL_UTILIZATION;
        } else {
            uint256 excessUtilization = utilization - OPTIMAL_UTILIZATION;
            uint256 maxExcess = BPS_DENOMINATOR - OPTIMAL_UTILIZATION;
            return BASE_RATE + RATE_SLOPE_1 + (excessUtilization * RATE_SLOPE_2) / maxExcess;
        }
    }
    
    /**
     * @notice Get current supply rate
     * @return rate Annual supply rate in basis points
     */
    function getSupplyRate() external view override returns (uint256) {
        uint256 utilization = getUtilizationRate();
        uint256 borrowRate = getBorrowRate();
        
        // Supply rate = borrow rate * utilization * (1 - spread)
        // Spread is 10% (platform takes 10% of interest)
        return (borrowRate * utilization * 9000) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
    }
    
    /**
     * @notice Get utilization rate
     * @return rate Utilization rate in basis points (10000 = 100%)
     */
    function getUtilizationRate() public view override returns (uint256) {
        if (totalDeposits == 0) return 0;
        return (totalBorrowed * BPS_DENOMINATOR) / totalDeposits;
    }
    
    /**
     * @notice Get total available liquidity
     * @return liquidity Available to borrow
     */
    function getAvailableLiquidity() public view override returns (uint256) {
        return totalDeposits > totalBorrowed ? totalDeposits - totalBorrowed : 0;
    }
    
    /**
     * @notice Get user's borrowed amount including accrued interest
     * @param user The user address
     * @return borrowed Amount borrowed including interest
     */
    function getBorrowedAmount(address user) public view override returns (uint256) {
        uint256 principal = borrowedAmount[user];
        if (principal == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - borrowTimestamp[user];
        uint256 rate = getBorrowRate();
        
        // Simple interest: principal * rate * time / year
        uint256 interest = (principal * rate * timeElapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        
        return principal + interest;
    }
    
    /**
     * @notice Get user's share balance
     * @param user The user address
     * @return shares User's LP shares
     */
    function getShareBalance(address user) external view returns (uint256) {
        return userShares[user];
    }
    
    /**
     * @notice Convert shares to underlying amount
     * @param shares Number of shares
     * @return amount Underlying stablecoin amount
     */
    function sharesToAmount(uint256 shares) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (shares * totalDeposits) / totalShares;
    }
    
    // ============ Internal Functions ============
    
    function _transferIn(address from, uint256 amount) internal {
        // In production, use SafeERC20
        (bool success, bytes memory data) = stablecoin.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer in failed");
    }
    
    function _transferOut(address to, uint256 amount) internal {
        // In production, use SafeERC20
        (bool success, bytes memory data) = stablecoin.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer out failed");
    }
}
