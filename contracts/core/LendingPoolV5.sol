// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LendingPoolV5
 * @notice Lending pool with E-Mode support for higher capital efficiency
 * @dev E-Mode allows 97% LTV for correlated assets (e.g., stablecoins)
 * 
 * Features:
 * - E-Mode categories with custom LTV/liquidation thresholds
 * - Variable interest rate model (kink-based)
 * - Bad debt insurance fund
 * - Flash loan support
 */
contract LendingPoolV5 is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ Constants ============
    
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    // Default interest rate parameters (non E-Mode)
    uint256 public constant BASE_RATE = 500;            // 5% base rate
    uint256 public constant RATE_SLOPE_1 = 2700;        // 27% slope below optimal
    uint256 public constant RATE_SLOPE_2 = 10000;       // 100% slope above optimal  
    uint256 public constant OPTIMAL_UTILIZATION = 8000; // 80% optimal
    
    // Default LTV parameters
    uint256 public constant DEFAULT_LTV = 8000;         // 80% LTV
    uint256 public constant DEFAULT_LIQUIDATION_THRESHOLD = 8500; // 85%
    uint256 public constant DEFAULT_LIQUIDATION_BONUS = 500;      // 5%
    
    // Insurance parameters
    uint256 public constant INSURANCE_FEE = 100;        // 1% of interest goes to insurance
    
    // Flash loan fee
    uint256 public constant FLASH_LOAN_FEE = 5;         // 0.05%
    
    // ============ E-Mode Structures ============
    
    /**
     * @notice E-Mode category configuration
     * @dev Allows higher LTV for correlated assets
     */
    struct EModeCategory {
        uint16 ltv;                     // Max LTV in BPS (e.g., 9700 = 97%)
        uint16 liquidationThreshold;    // Liquidation threshold in BPS
        uint16 liquidationBonus;        // Liquidation bonus in BPS (e.g., 100 = 1%)
        address priceSource;            // Optional custom price oracle
        string label;                   // Human readable label
    }
    
    /**
     * @notice User position data
     */
    struct UserPosition {
        uint256 shares;                 // LP shares
        uint256 borrowed;               // Amount borrowed
        uint8 eMode;                    // E-Mode category (0 = disabled)
        uint256 lastInterestTime;       // Last interest accrual
    }
    
    // ============ State Variables ============
    
    address public owner;
    address public vault;
    IERC20 public immutable asset;
    
    // Pool state
    uint256 public totalDeposits;
    uint256 public totalBorrowed;
    uint256 public totalShares;
    uint256 public lastAccrualTime;
    uint256 public insuranceFund;
    uint256 public totalBadDebt;
    
    // E-Mode state
    mapping(uint8 => EModeCategory) public eModeCategories;
    uint8 public nextEModeCategoryId = 1;
    
    // User state
    mapping(address => UserPosition) public userPositions;
    mapping(address => uint256) public userShares; // Legacy compatibility
    
    // Flash loan state
    bool private _flashLoanActive;
    
    // ============ Events ============
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event BadDebtCovered(uint256 amount, uint256 fromInsurance, uint256 socialized);
    event InsuranceFunded(uint256 amount);
    event VaultSet(address indexed vault);
    
    // E-Mode events
    event EModeCategoryAdded(uint8 indexed categoryId, string label, uint16 ltv, uint16 liquidationThreshold);
    event EModeCategoryUpdated(uint8 indexed categoryId, uint16 ltv, uint16 liquidationThreshold);
    event UserEModeChanged(address indexed user, uint8 oldCategory, uint8 newCategory);
    
    // Flash loan events
    event FlashLoan(address indexed receiver, uint256 amount, uint256 fee);
    
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
    
    constructor(address _asset) {
        require(_asset != address(0), "Invalid asset");
        owner = msg.sender;
        asset = IERC20(_asset);
        lastAccrualTime = block.timestamp;
        
        // Initialize default E-Mode categories
        _initializeDefaultEModes();
    }
    
    function _initializeDefaultEModes() internal {
        // Category 1: Stablecoins (USDT, USDC, BUSD)
        eModeCategories[1] = EModeCategory({
            ltv: 9700,                  // 97% LTV
            liquidationThreshold: 9750, // 97.5%
            liquidationBonus: 100,      // 1%
            priceSource: address(0),    // Use default oracle
            label: "Stablecoins"
        });
        
        // Category 2: ETH Correlated (ETH, stETH, wstETH)
        eModeCategories[2] = EModeCategory({
            ltv: 9300,                  // 93% LTV
            liquidationThreshold: 9500, // 95%
            liquidationBonus: 100,      // 1%
            priceSource: address(0),
            label: "ETH Correlated"
        });
        
        // Category 3: BTC Correlated (BTC, BTCB, WBTC)
        eModeCategories[3] = EModeCategory({
            ltv: 9300,                  // 93% LTV
            liquidationThreshold: 9500, // 95%
            liquidationBonus: 100,      // 1%
            priceSource: address(0),
            label: "BTC Correlated"
        });
        
        nextEModeCategoryId = 4;
    }
    
    // ============ Admin Functions ============
    
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        vault = _vault;
        emit VaultSet(_vault);
    }
    
    /**
     * @notice Add a new E-Mode category
     * @param ltv Maximum LTV in BPS
     * @param liquidationThreshold Liquidation threshold in BPS
     * @param liquidationBonus Liquidation bonus in BPS
     * @param priceSource Custom price oracle (optional)
     * @param label Human readable label
     */
    function addEModeCategory(
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus,
        address priceSource,
        string calldata label
    ) external onlyOwner returns (uint8 categoryId) {
        require(ltv <= 9900, "LTV too high");
        require(liquidationThreshold > ltv, "Invalid threshold");
        require(liquidationBonus <= 1000, "Bonus too high");
        
        categoryId = nextEModeCategoryId++;
        
        eModeCategories[categoryId] = EModeCategory({
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            priceSource: priceSource,
            label: label
        });
        
        emit EModeCategoryAdded(categoryId, label, ltv, liquidationThreshold);
    }
    
    /**
     * @notice Update an existing E-Mode category
     */
    function updateEModeCategory(
        uint8 categoryId,
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus
    ) external onlyOwner {
        require(categoryId > 0 && categoryId < nextEModeCategoryId, "Invalid category");
        require(ltv <= 9900, "LTV too high");
        require(liquidationThreshold > ltv, "Invalid threshold");
        
        EModeCategory storage category = eModeCategories[categoryId];
        category.ltv = ltv;
        category.liquidationThreshold = liquidationThreshold;
        category.liquidationBonus = liquidationBonus;
        
        emit EModeCategoryUpdated(categoryId, ltv, liquidationThreshold);
    }
    
    // ============ User E-Mode Functions ============
    
    /**
     * @notice Set user's E-Mode category
     * @param categoryId E-Mode category (0 to disable)
     */
    function setUserEMode(uint8 categoryId) external {
        require(categoryId == 0 || categoryId < nextEModeCategoryId, "Invalid category");
        
        UserPosition storage position = userPositions[msg.sender];
        uint8 oldCategory = position.eMode;
        
        // If user has active borrow, verify new category is safe
        if (position.borrowed > 0 && categoryId != oldCategory) {
            // Check that position would still be healthy with new E-Mode
            uint256 collateralValue = _getCollateralValue(msg.sender);
            uint256 maxBorrow = _calculateMaxBorrow(collateralValue, categoryId);
            require(position.borrowed <= maxBorrow, "Position would be unhealthy");
        }
        
        position.eMode = categoryId;
        
        emit UserEModeChanged(msg.sender, oldCategory, categoryId);
    }
    
    /**
     * @notice Get user's current E-Mode category
     */
    function getUserEMode(address user) external view returns (uint8) {
        return userPositions[user].eMode;
    }
    
    /**
     * @notice Get E-Mode category details
     */
    function getEModeCategory(uint8 categoryId) external view returns (
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus,
        string memory label
    ) {
        EModeCategory storage category = eModeCategories[categoryId];
        return (
            category.ltv,
            category.liquidationThreshold,
            category.liquidationBonus,
            category.label
        );
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Get LTV for a user based on their E-Mode
     */
    function getUserLTV(address user) public view returns (uint256) {
        uint8 eMode = userPositions[user].eMode;
        if (eMode == 0) {
            return DEFAULT_LTV;
        }
        return eModeCategories[eMode].ltv;
    }
    
    /**
     * @notice Get liquidation threshold for a user
     */
    function getUserLiquidationThreshold(address user) public view returns (uint256) {
        uint8 eMode = userPositions[user].eMode;
        if (eMode == 0) {
            return DEFAULT_LIQUIDATION_THRESHOLD;
        }
        return eModeCategories[eMode].liquidationThreshold;
    }
    
    /**
     * @notice Calculate max borrow based on collateral and E-Mode
     */
    function _calculateMaxBorrow(uint256 collateralValue, uint8 eMode) internal view returns (uint256) {
        uint256 ltv = eMode == 0 ? DEFAULT_LTV : eModeCategories[eMode].ltv;
        return (collateralValue * ltv) / BPS_DENOMINATOR;
    }
    
    /**
     * @notice Get collateral value for a user
     */
    function _getCollateralValue(address user) internal view returns (uint256) {
        uint256 shares = userPositions[user].shares;
        if (shares == 0 || totalShares == 0) return 0;
        return (shares * totalDeposits) / totalShares;
    }
    
    // ============ Deposit/Withdraw Functions ============
    
    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        require(amount > 0, "Zero amount");
        
        _accrueInterest();
        
        asset.safeTransferFrom(msg.sender, address(this), amount);
        
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalDeposits;
        }
        
        totalShares += shares;
        totalDeposits += amount;
        userPositions[msg.sender].shares += shares;
        userShares[msg.sender] += shares; // Legacy compatibility
        
        emit Deposited(msg.sender, amount, shares);
    }
    
    function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
        require(shares > 0, "Zero shares");
        require(userPositions[msg.sender].shares >= shares, "Insufficient shares");
        
        _accrueInterest();
        
        amount = (shares * totalDeposits) / totalShares;
        
        // Check if withdrawal would make position unhealthy
        UserPosition storage position = userPositions[msg.sender];
        if (position.borrowed > 0) {
            uint256 remainingShares = position.shares - shares;
            uint256 remainingCollateral = totalShares > shares 
                ? (remainingShares * totalDeposits) / (totalShares - shares)
                : 0;
            uint256 maxBorrow = _calculateMaxBorrow(remainingCollateral, position.eMode);
            require(position.borrowed <= maxBorrow, "Would be undercollateralized");
        }
        
        uint256 available = asset.balanceOf(address(this));
        require(amount <= available, "Insufficient liquidity");
        
        totalShares -= shares;
        totalDeposits -= amount;
        position.shares -= shares;
        userShares[msg.sender] -= shares; // Legacy compatibility
        
        asset.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, shares);
    }
    
    // ============ Borrow/Repay Functions ============
    
    function borrow(uint256 amount) external onlyVault {
        _accrueInterest();
        
        uint256 available = asset.balanceOf(address(this));
        require(amount <= available, "Insufficient liquidity");
        
        totalBorrowed += amount;
        
        asset.safeTransfer(vault, amount);
        
        emit Borrowed(vault, amount);
    }
    
    function repay(uint256 amount) external onlyVault {
        _accrueInterest();
        
        asset.safeTransferFrom(vault, address(this), amount);
        
        if (amount > totalBorrowed) {
            totalBorrowed = 0;
        } else {
            totalBorrowed -= amount;
        }
        
        emit Repaid(vault, amount);
    }
    
    // ============ Flash Loan Functions ============
    
    /**
     * @notice Execute a flash loan
     * @param receiver Contract that will receive and repay the loan
     * @param amount Amount to borrow
     * @param params Arbitrary data to pass to receiver
     */
    function flashLoan(
        address receiver,
        uint256 amount,
        bytes calldata params
    ) external nonReentrant {
        require(!_flashLoanActive, "Flash loan in progress");
        require(amount > 0, "Zero amount");
        
        uint256 available = asset.balanceOf(address(this));
        require(amount <= available, "Insufficient liquidity");
        
        _flashLoanActive = true;
        
        uint256 fee = (amount * FLASH_LOAN_FEE) / BPS_DENOMINATOR;
        uint256 balanceBefore = asset.balanceOf(address(this));
        
        // Transfer to receiver
        asset.safeTransfer(receiver, amount);
        
        // Call receiver and verify return value
        bool success = IFlashLoanReceiver(receiver).executeOperation(
            address(asset),
            amount,
            fee,
            msg.sender,
            params
        );
        require(success, "Flash loan execution failed");
        
        // Verify repayment
        uint256 balanceAfter = asset.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid");
        
        // Add fee to deposits (benefit LPs)
        totalDeposits += fee;
        
        _flashLoanActive = false;
        
        emit FlashLoan(receiver, amount, fee);
    }
    
    // ============ Interest Functions ============
    
    function _accrueInterest() internal {
        uint256 timeElapsed = block.timestamp - lastAccrualTime;
        if (timeElapsed == 0 || totalBorrowed == 0) {
            lastAccrualTime = block.timestamp;
            return;
        }
        
        uint256 borrowRate = getBorrowRate();
        uint256 interest = (totalBorrowed * borrowRate * timeElapsed) / (BPS_DENOMINATOR * SECONDS_PER_YEAR);
        
        // Insurance fee
        uint256 insuranceCut = (interest * INSURANCE_FEE) / BPS_DENOMINATOR;
        insuranceFund += insuranceCut;
        
        // Net interest to depositors
        uint256 depositorInterest = interest - insuranceCut;
        totalDeposits += depositorInterest;
        totalBorrowed += interest;
        
        lastAccrualTime = block.timestamp;
        
        emit InsuranceFunded(insuranceCut);
    }
    
    function getBorrowRate() public view returns (uint256) {
        if (totalDeposits == 0) return BASE_RATE;
        
        uint256 utilization = (totalBorrowed * BPS_DENOMINATOR) / totalDeposits;
        
        if (utilization <= OPTIMAL_UTILIZATION) {
            return BASE_RATE + (utilization * RATE_SLOPE_1) / OPTIMAL_UTILIZATION;
        } else {
            uint256 excessUtilization = utilization - OPTIMAL_UTILIZATION;
            uint256 maxExcess = BPS_DENOMINATOR - OPTIMAL_UTILIZATION;
            return BASE_RATE + RATE_SLOPE_1 + (excessUtilization * RATE_SLOPE_2) / maxExcess;
        }
    }
    
    function getSupplyRate() public view returns (uint256) {
        if (totalDeposits == 0) return 0;
        
        uint256 utilization = (totalBorrowed * BPS_DENOMINATOR) / totalDeposits;
        uint256 borrowRate = getBorrowRate();
        
        // Supply rate = borrow rate * utilization * (1 - insurance fee)
        return (borrowRate * utilization * (BPS_DENOMINATOR - INSURANCE_FEE)) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
    }
    
    // ============ View Functions ============
    
    function getUtilization() external view returns (uint256) {
        if (totalDeposits == 0) return 0;
        return (totalBorrowed * BPS_DENOMINATOR) / totalDeposits;
    }
    
    function getUserMaxBorrow(address user) external view returns (uint256) {
        uint256 collateralValue = _getCollateralValue(user);
        return _calculateMaxBorrow(collateralValue, userPositions[user].eMode);
    }
    
    function getHealthFactor(address user) external view returns (uint256) {
        UserPosition storage position = userPositions[user];
        if (position.borrowed == 0) return type(uint256).max;
        
        uint256 collateralValue = _getCollateralValue(user);
        uint256 threshold = getUserLiquidationThreshold(user);
        uint256 maxDebt = (collateralValue * threshold) / BPS_DENOMINATOR;
        
        return (maxDebt * 1e18) / position.borrowed;
    }
    
    function balanceOf(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userPositions[user].shares * totalDeposits) / totalShares;
    }
}

// ============ Interfaces ============

interface IFlashLoanReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}
