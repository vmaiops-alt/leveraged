// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LendingPoolV2
 * @notice Lending pool with interface matching LeveragedFarmV2
 */
contract LendingPoolV2 {
    using SafeERC20 for IERC20;
    
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
    IERC20 public immutable stablecoin;
    
    uint256 public totalDeposits;
    uint256 public totalBorrowed;
    uint256 public totalShares;
    uint256 public lastAccrualTime;
    
    mapping(address => uint256) public userShares;
    
    // ============ Events ============
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event Borrowed(uint256 amount);
    event Repaid(uint256 amount);
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
        stablecoin = IERC20(_stablecoin);
        lastAccrualTime = block.timestamp;
    }
    
    // ============ Admin Functions ============
    
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        vault = _vault;
        emit VaultSet(_vault);
    }
    
    // ============ Depositor Functions ============
    
    function deposit(uint256 amount) external returns (uint256 shares) {
        require(amount > 0, "Zero amount");
        
        _accrueInterest();
        
        stablecoin.safeTransferFrom(msg.sender, address(this), amount);
        
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalDeposits;
        }
        
        totalDeposits += amount;
        totalShares += shares;
        userShares[msg.sender] += shares;
        
        emit Deposited(msg.sender, amount, shares);
    }
    
    function withdraw(uint256 shares) external returns (uint256 amount) {
        require(shares > 0, "Zero shares");
        require(userShares[msg.sender] >= shares, "Insufficient shares");
        
        _accrueInterest();
        
        amount = (shares * totalDeposits) / totalShares;
        require(amount <= getAvailableLiquidity(), "Insufficient liquidity");
        
        totalDeposits -= amount;
        totalShares -= shares;
        userShares[msg.sender] -= shares;
        
        stablecoin.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, shares);
    }
    
    // ============ Vault Functions (Interface matches LeveragedFarmV2) ============
    
    /**
     * @notice Borrow stablecoins - called by LeveragedFarmV2
     * @param amount Amount to borrow
     */
    function borrow(uint256 amount) external onlyVault {
        require(amount > 0, "Zero amount");
        require(amount <= getAvailableLiquidity(), "Insufficient liquidity");
        
        _accrueInterest();
        
        totalBorrowed += amount;
        
        stablecoin.safeTransfer(vault, amount);
        
        emit Borrowed(amount);
    }
    
    /**
     * @notice Repay borrowed amount - called by LeveragedFarmV2
     * @param amount Amount to repay
     */
    function repay(uint256 amount) external onlyVault {
        require(amount > 0, "Zero amount");
        
        _accrueInterest();
        
        stablecoin.safeTransferFrom(vault, address(this), amount);
        
        // Amount might include interest, cap at totalBorrowed for principal tracking
        uint256 principalRepaid = amount > totalBorrowed ? totalBorrowed : amount;
        uint256 interest = amount > principalRepaid ? amount - principalRepaid : 0;
        
        totalBorrowed -= principalRepaid;
        totalDeposits += interest; // Interest goes to depositors
        
        emit Repaid(amount);
    }
    
    // ============ Interest Accrual ============
    
    function _accrueInterest() internal {
        if (totalBorrowed == 0) {
            lastAccrualTime = block.timestamp;
            return;
        }
        
        uint256 timeElapsed = block.timestamp - lastAccrualTime;
        if (timeElapsed == 0) return;
        
        uint256 borrowRate = getBorrowRate();
        uint256 interest = (totalBorrowed * borrowRate * timeElapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        
        // Interest accrues to depositors
        totalDeposits += interest;
        totalBorrowed += interest;
        
        lastAccrualTime = block.timestamp;
    }
    
    // ============ View Functions ============
    
    function getBorrowRate() public view returns (uint256) {
        uint256 utilization = getUtilizationRate();
        
        if (utilization <= OPTIMAL_UTILIZATION) {
            return BASE_RATE + (utilization * RATE_SLOPE_1) / OPTIMAL_UTILIZATION;
        } else {
            uint256 excessUtilization = utilization - OPTIMAL_UTILIZATION;
            uint256 maxExcess = BPS_DENOMINATOR - OPTIMAL_UTILIZATION;
            return BASE_RATE + RATE_SLOPE_1 + (excessUtilization * RATE_SLOPE_2) / maxExcess;
        }
    }
    
    function getSupplyRate() external view returns (uint256) {
        uint256 utilization = getUtilizationRate();
        uint256 borrowRate = getBorrowRate();
        return (borrowRate * utilization * 9000) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
    }
    
    function getUtilizationRate() public view returns (uint256) {
        if (totalDeposits == 0) return 0;
        return (totalBorrowed * BPS_DENOMINATOR) / totalDeposits;
    }
    
    function getAvailableLiquidity() public view returns (uint256) {
        return totalDeposits > totalBorrowed ? totalDeposits - totalBorrowed : 0;
    }
    
    function balanceOf(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userShares[user] * totalDeposits) / totalShares;
    }
}
