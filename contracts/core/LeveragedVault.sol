// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/ILeveragedVault.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IValueTracker.sol";

/**
 * @title LeveragedVault
 * @notice Main vault contract for leveraged yield farming
 * @dev Handles deposits, leverage, and position management
 */
contract LeveragedVault is ILeveragedVault {
    
    // ============ Constants ============
    
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_LEVERAGE = 10000;   // 1x
    uint256 public constant MAX_LEVERAGE = 50000;   // 5x
    uint256 public constant LIQUIDATION_THRESHOLD = 11000; // Health factor 1.1
    uint256 public constant LIQUIDATION_BONUS = 500;       // 5% bonus for liquidators
    uint256 public constant ENTRY_FEE_BPS = 10;            // 0.1% entry fee
    uint256 public constant PERFORMANCE_FEE_BPS = 1000;    // 10% performance fee on yield
    
    // ============ State ============
    
    address public owner;
    address public stablecoin;      // USDT/USDC for deposits
    ILendingPool public lendingPool;
    IPriceOracle public priceOracle;
    IValueTracker public valueTracker;
    address public feeCollector;
    
    uint256 public nextPositionId;
    bool public paused;
    
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositionIds;
    mapping(address => bool) public supportedAssets;
    
    // ============ Events ============
    
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event AssetSupported(address indexed asset, bool supported);
    event FeeCollectorSet(address indexed feeCollector);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }
    
    modifier onlyPositionOwner(uint256 positionId) {
        require(positions[positionId].user == msg.sender, "Not position owner");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _stablecoin,
        address _lendingPool,
        address _priceOracle,
        address _valueTracker
    ) {
        owner = msg.sender;
        stablecoin = _stablecoin;
        lendingPool = ILendingPool(_lendingPool);
        priceOracle = IPriceOracle(_priceOracle);
        valueTracker = IValueTracker(_valueTracker);
        feeCollector = msg.sender;
    }
    
    // ============ Admin Functions ============
    
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
    
    function setSupportedAsset(address asset, bool supported) external onlyOwner {
        supportedAssets[asset] = supported;
        emit AssetSupported(asset, supported);
    }
    
    function setFeeCollector(address _feeCollector) external onlyOwner {
        require(_feeCollector != address(0), "Invalid fee collector");
        feeCollector = _feeCollector;
        emit FeeCollectorSet(_feeCollector);
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Open a new leveraged position
     * @param asset The asset to get exposure to (BTC, ETH, etc.)
     * @param amount Amount of stablecoin to deposit
     * @param leverage Leverage multiplier in basis points (10000 = 1x, 50000 = 5x)
     * @return positionId The ID of the new position
     */
    function openPosition(
        address asset,
        uint256 amount,
        uint256 leverage
    ) external override whenNotPaused returns (uint256 positionId) {
        // Validations
        require(supportedAssets[asset], "Asset not supported");
        require(amount > 0, "Zero amount");
        require(leverage >= MIN_LEVERAGE && leverage <= MAX_LEVERAGE, "Invalid leverage");
        
        // Transfer deposit from user
        _transferIn(msg.sender, amount);
        
        // Calculate entry fee (0.1%)
        uint256 entryFee = (amount * ENTRY_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netDeposit = amount - entryFee;
        
        // Transfer fee to collector
        if (entryFee > 0) {
            _transferOut(feeCollector, entryFee);
        }
        
        // Calculate total exposure and borrow amount
        uint256 totalExposure = (netDeposit * leverage) / MIN_LEVERAGE;
        uint256 borrowAmount = totalExposure - netDeposit;
        
        // Borrow from lending pool if leverage > 1x
        if (borrowAmount > 0) {
            // Transfer deposit to lending pool as collateral
            _transferOut(address(lendingPool), netDeposit);
            
            // Borrow additional funds
            lendingPool.borrow(borrowAmount, msg.sender);
        }
        
        // Get entry price
        uint256 entryPrice = priceOracle.getPrice(asset);
        
        // Create position
        positionId = nextPositionId++;
        positions[positionId] = Position({
            user: msg.sender,
            asset: asset,
            depositAmount: netDeposit,
            leverageMultiplier: leverage,
            totalExposure: totalExposure,
            borrowedAmount: borrowAmount,
            entryPrice: entryPrice,
            entryTimestamp: block.timestamp,
            isActive: true
        });
        
        userPositionIds[msg.sender].push(positionId);
        
        // Record entry value for fee tracking
        valueTracker.recordEntry(positionId, asset, totalExposure);
        
        emit PositionOpened(
            positionId,
            msg.sender,
            asset,
            netDeposit,
            leverage,
            entryPrice
        );
    }
    
    /**
     * @notice Close a position and withdraw funds
     * @param positionId The position to close
     */
    function closePosition(uint256 positionId) 
        external 
        override 
        onlyPositionOwner(positionId) 
    {
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        
        // Get current price
        uint256 currentPrice = priceOracle.getPrice(position.asset);
        
        // Calculate value increase and platform fee
        (
            uint256 valueIncrease,
            uint256 platformFee,
            uint256 userValueGain
        ) = valueTracker.calculateValueIncrease(positionId, currentPrice);
        
        // Calculate total position value at current price
        // positionValue = totalExposure * currentPrice / entryPrice
        uint256 currentValue = (position.totalExposure * currentPrice) / position.entryPrice;
        
        // Repay borrowed amount
        uint256 borrowedWithInterest = 0;
        if (position.borrowedAmount > 0) {
            borrowedWithInterest = lendingPool.getBorrowedAmount(msg.sender);
            lendingPool.repay(borrowedWithInterest, msg.sender);
        }
        
        // Calculate user payout
        // userPayout = currentValue - borrowedWithInterest - platformFee
        uint256 userPayout = 0;
        if (currentValue > borrowedWithInterest + platformFee) {
            userPayout = currentValue - borrowedWithInterest - platformFee;
        }
        
        // Transfer platform fee
        if (platformFee > 0) {
            _transferOut(feeCollector, platformFee);
        }
        
        // Transfer payout to user
        if (userPayout > 0) {
            _transferOut(msg.sender, userPayout);
        }
        
        // Mark position as closed
        position.isActive = false;
        
        emit PositionClosed(
            positionId,
            msg.sender,
            currentPrice,
            valueIncrease,
            platformFee,
            userPayout
        );
    }
    
    /**
     * @notice Add collateral to an existing position
     * @param positionId The position to add collateral to
     * @param amount Amount of collateral to add
     */
    function addCollateral(uint256 positionId, uint256 amount) 
        external 
        override 
        onlyPositionOwner(positionId)
        whenNotPaused 
    {
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        require(amount > 0, "Zero amount");
        
        // Transfer collateral from user
        _transferIn(msg.sender, amount);
        
        // Add to deposit
        position.depositAmount += amount;
        position.totalExposure += amount;
        
        emit CollateralAdded(positionId, amount);
    }
    
    /**
     * @notice Liquidate an unhealthy position
     * @param positionId The position to liquidate
     */
    function liquidate(uint256 positionId) external whenNotPaused {
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        require(isLiquidatable(positionId), "Not liquidatable");
        
        // Get current price
        uint256 currentPrice = priceOracle.getPrice(position.asset);
        
        // Calculate current position value
        uint256 currentValue = (position.totalExposure * currentPrice) / position.entryPrice;
        
        // Repay borrowed amount
        uint256 borrowedWithInterest = lendingPool.getBorrowedAmount(position.user);
        if (borrowedWithInterest > 0) {
            lendingPool.repay(borrowedWithInterest, position.user);
        }
        
        // Calculate liquidation bonus for liquidator (5%)
        uint256 liquidationBonus = (currentValue * LIQUIDATION_BONUS) / BPS_DENOMINATOR;
        
        // Transfer bonus to liquidator
        if (liquidationBonus > 0) {
            _transferOut(msg.sender, liquidationBonus);
        }
        
        // Remaining goes to fee collector (bad debt buffer)
        uint256 remaining = currentValue > borrowedWithInterest + liquidationBonus 
            ? currentValue - borrowedWithInterest - liquidationBonus 
            : 0;
        if (remaining > 0) {
            _transferOut(feeCollector, remaining);
        }
        
        // Mark position as closed
        position.isActive = false;
        
        emit PositionLiquidated(
            positionId,
            position.user,
            msg.sender,
            currentPrice
        );
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get position details
     * @param positionId The position ID
     * @return position The position struct
     */
    function getPosition(uint256 positionId) external view override returns (Position memory) {
        return positions[positionId];
    }
    
    /**
     * @notice Calculate health factor for a position
     * @param positionId The position ID
     * @return healthFactor Health factor (10000 = 1.0)
     */
    function getHealthFactor(uint256 positionId) public view override returns (uint256) {
        Position memory position = positions[positionId];
        if (!position.isActive) return 0;
        if (position.borrowedAmount == 0) return type(uint256).max;
        
        // Get current price
        uint256 currentPrice = priceOracle.getPrice(position.asset);
        
        // Calculate current collateral value
        uint256 currentValue = (position.totalExposure * currentPrice) / position.entryPrice;
        
        // Get total debt
        uint256 totalDebt = lendingPool.getBorrowedAmount(position.user);
        
        if (totalDebt == 0) return type(uint256).max;
        
        // Health factor = collateral value / debt
        return (currentValue * BPS_DENOMINATOR) / totalDebt;
    }
    
    /**
     * @notice Check if a position can be liquidated
     * @param positionId The position ID
     * @return canLiquidate True if position is liquidatable
     */
    function isLiquidatable(uint256 positionId) public view override returns (bool) {
        uint256 healthFactor = getHealthFactor(positionId);
        return healthFactor < LIQUIDATION_THRESHOLD && healthFactor > 0;
    }
    
    /**
     * @notice Get all positions for a user
     * @param user The user address
     * @return positionIds Array of position IDs
     */
    function getUserPositions(address user) external view override returns (uint256[] memory) {
        return userPositionIds[user];
    }
    
    /**
     * @notice Get position P&L
     * @param positionId The position ID
     * @return pnl Profit/Loss in stablecoin terms (can be negative as int)
     * @return pnlPercent P&L percentage in BPS
     */
    function getPositionPnL(uint256 positionId) external view returns (int256 pnl, int256 pnlPercent) {
        Position memory position = positions[positionId];
        if (!position.isActive) return (0, 0);
        
        uint256 currentPrice = priceOracle.getPrice(position.asset);
        uint256 currentValue = (position.totalExposure * currentPrice) / position.entryPrice;
        uint256 borrowedWithInterest = lendingPool.getBorrowedAmount(position.user);
        
        // PnL = currentValue - deposit - borrowedWithInterest
        int256 rawPnL = int256(currentValue) - int256(position.depositAmount) - int256(borrowedWithInterest);
        
        pnl = rawPnL;
        pnlPercent = (rawPnL * int256(BPS_DENOMINATOR)) / int256(position.depositAmount);
    }
    
    // ============ Internal Functions ============
    
    function _transferIn(address from, uint256 amount) internal {
        (bool success, bytes memory data) = stablecoin.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer in failed");
    }
    
    function _transferOut(address to, uint256 amount) internal {
        (bool success, bytes memory data) = stablecoin.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer out failed");
    }
}
