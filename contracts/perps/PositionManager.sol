// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPerpVault {
    function reserveLiquidity(address token, uint256 amount) external;
    function releaseLiquidity(address token, uint256 amount) external;
    function transferOut(address token, address to, uint256 amount) external;
    function transferIn(address token, uint256 amount) external;
    function collectTradingFees(uint256 usdAmount) external;
    function marginFee() external view returns (uint256);
}

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

/**
 * @title PositionManager
 * @notice Manages leveraged long/short positions for perpetual trading
 * @dev Handles position lifecycle: open, increase, decrease, close, liquidate
 * 
 * Position Types:
 * - Long: Profit when price goes up
 * - Short: Profit when price goes down
 * 
 * Leverage:
 * - Up to 50x leverage
 * - Collateral determines max position size
 * - Liquidation when margin ratio falls below threshold
 */
contract PositionManager is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    // ============ Structs ============
    
    struct Position {
        address account;            // Position owner
        address collateralToken;    // Token used as collateral
        address indexToken;         // Token being longed/shorted
        bool isLong;                // Long or short
        uint256 size;               // Position size in USD (30 decimals)
        uint256 collateral;         // Collateral in USD (30 decimals)
        uint256 averagePrice;       // Average entry price (30 decimals)
        int256 entryFundingRate;    // Funding rate at entry (signed for negative rates)
        uint256 lastUpdated;        // Last update timestamp
    }
    
    // ============ State Variables ============
    
    /// @notice Vault contract
    IPerpVault public vault;
    
    /// @notice Price oracle
    IPriceOracle public priceOracle;
    
    /// @notice All positions
    mapping(bytes32 => Position) public positions;
    
    /// @notice User's position keys
    mapping(address => bytes32[]) public userPositions;
    
    /// @notice Next position ID
    uint256 public nextPositionId;
    
    /// @notice Cumulative funding rate per token (scaled by 1e18)
    mapping(address => int256) public cumulativeFundingRates;
    
    /// @notice Last funding update time
    mapping(address => uint256) public lastFundingTimes;
    
    /// @notice Open interest for longs
    mapping(address => uint256) public longOpenInterest;
    
    /// @notice Open interest for shorts
    mapping(address => uint256) public shortOpenInterest;
    
    // ============ Constants ============
    
    uint256 public constant PRICE_PRECISION = 1e30;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant FUNDING_INTERVAL = 1 hours;
    uint256 public constant MAX_LEVERAGE = 50;
    
    /// @notice Minimum margin ratio before liquidation (5%)
    uint256 public liquidationThreshold = 500;
    
    /// @notice Liquidation fee (1%)
    uint256 public liquidationFee = 100;
    
    /// @notice Funding rate factor (0.01% per hour per 1% imbalance)
    uint256 public fundingRateFactor = 100;
    
    /// @notice Maximum price age before considered stale (10 minutes)
    uint256 public maxPriceAge = 10 minutes;
    
    /// @notice Track total bad debt
    uint256 public totalBadDebt;
    
    // ============ Events ============
    
    event PositionOpened(
        bytes32 indexed positionKey,
        address indexed account,
        address indexToken,
        bool isLong,
        uint256 size,
        uint256 collateral
    );
    event PositionIncreased(bytes32 indexed positionKey, uint256 sizeDelta, uint256 collateralDelta);
    event PositionDecreased(bytes32 indexed positionKey, uint256 sizeDelta, uint256 collateralDelta, int256 pnl);
    event PositionClosed(bytes32 indexed positionKey, int256 pnl);
    event PositionLiquidated(bytes32 indexed positionKey, address liquidator, int256 pnl);
    event FundingUpdated(address indexed token, int256 fundingRate);
    event BadDebtRecorded(bytes32 indexed positionKey, uint256 amount);
    
    // ============ Errors ============
    
    error PositionNotFound();
    error InsufficientCollateral();
    error MaxLeverageExceeded();
    error PositionTooSmall();
    error NotLiquidatable();
    error Unauthorized();
    error ZeroAmount();
    
    // ============ Constructor ============
    
    constructor(address _vault, address _priceOracle) Ownable(msg.sender) {
        vault = IPerpVault(_vault);
        priceOracle = IPriceOracle(_priceOracle);
    }
    
    // ============ Position Functions ============
    
    /**
     * @notice Open a new position
     * @param _collateralToken Token to use as collateral
     * @param _indexToken Token to long/short
     * @param _collateralAmount Collateral amount
     * @param _sizeDelta Position size in USD
     * @param _isLong True for long, false for short
     */
    function openPosition(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralAmount,
        uint256 _sizeDelta,
        bool _isLong
    ) external nonReentrant returns (bytes32 positionKey) {
        if (_collateralAmount == 0 || _sizeDelta == 0) revert ZeroAmount();
        
        // Update funding
        _updateFunding(_indexToken);
        
        // Transfer collateral
        IERC20(_collateralToken).safeTransferFrom(msg.sender, address(vault), _collateralAmount);
        vault.transferIn(_collateralToken, _collateralAmount);
        
        // Calculate collateral in USD
        uint256 collateralPrice = priceOracle.getPrice(_collateralToken);
        uint256 collateralUsd = (_collateralAmount * collateralPrice) / PRICE_PRECISION;
        
        // Check leverage BEFORE fee deduction to ensure user intended leverage is valid
        uint256 fee = (_sizeDelta * vault.marginFee()) / BASIS_POINTS;
        uint256 collateralAfterFees = collateralUsd - fee;
        require(collateralAfterFees > 0, "Fee exceeds collateral");
        
        uint256 leverage = (_sizeDelta * BASIS_POINTS) / collateralAfterFees;
        if (leverage > MAX_LEVERAGE * BASIS_POINTS) revert MaxLeverageExceeded();
        
        // Collect fees after leverage check passes
        vault.collectTradingFees(fee);
        collateralUsd = collateralAfterFees;
        
        // Get index price
        uint256 indexPrice = priceOracle.getPrice(_indexToken);
        
        // Create position
        positionKey = _getPositionKey(msg.sender, _collateralToken, _indexToken, _isLong);
        
        Position storage position = positions[positionKey];
        if (position.size == 0) {
            // New position
            position.account = msg.sender;
            position.collateralToken = _collateralToken;
            position.indexToken = _indexToken;
            position.isLong = _isLong;
            position.averagePrice = indexPrice;
            position.entryFundingRate = cumulativeFundingRates[_indexToken];
            userPositions[msg.sender].push(positionKey);
        } else {
            // Increase existing - calculate new average price
            position.averagePrice = _getNextAveragePrice(
                position.size,
                position.averagePrice,
                _sizeDelta,
                indexPrice
            );
        }
        
        position.size += _sizeDelta;
        position.collateral += collateralUsd;
        position.lastUpdated = block.timestamp;
        
        // Update open interest
        if (_isLong) {
            longOpenInterest[_indexToken] += _sizeDelta;
            vault.reserveLiquidity(_indexToken, (_sizeDelta * PRICE_PRECISION) / indexPrice);
        } else {
            shortOpenInterest[_indexToken] += _sizeDelta;
        }
        
        emit PositionOpened(positionKey, msg.sender, _indexToken, _isLong, position.size, position.collateral);
    }
    
    /**
     * @notice Decrease or close a position
     * @param _positionKey Position key
     * @param _sizeDelta Size to decrease
     * @param _collateralDelta Collateral to withdraw
     */
    function decreasePosition(
        bytes32 _positionKey,
        uint256 _sizeDelta,
        uint256 _collateralDelta
    ) external nonReentrant returns (int256 pnl) {
        Position storage position = positions[_positionKey];
        if (position.account != msg.sender) revert Unauthorized();
        if (position.size == 0) revert PositionNotFound();
        
        // Cache position data before potential deletion
        address posAccount = position.account;
        address posCollateralToken = position.collateralToken;
        
        // Update funding
        _updateFunding(position.indexToken);
        
        // Calculate PnL
        uint256 currentPrice = priceOracle.getPrice(position.indexToken);
        pnl = _calculatePnL(position, currentPrice, _sizeDelta);
        
        // Calculate funding payment
        int256 fundingPayment = _calculateFundingPayment(position);
        pnl -= fundingPayment;
        
        // Collect fees
        uint256 fee = (_sizeDelta * vault.marginFee()) / BASIS_POINTS;
        vault.collectTradingFees(fee);
        
        // Update position
        if (_sizeDelta == position.size) {
            // Close entire position
            _closePosition(_positionKey, pnl);
            emit PositionClosed(_positionKey, pnl);
        } else {
            // Partial close
            position.size -= _sizeDelta;
            position.collateral -= _collateralDelta;
            
            // Ensure still above liquidation threshold
            _validatePosition(position, currentPrice);
            
            // Update open interest
            if (position.isLong) {
                longOpenInterest[position.indexToken] -= _sizeDelta;
                vault.releaseLiquidity(position.indexToken, (_sizeDelta * PRICE_PRECISION) / currentPrice);
            } else {
                shortOpenInterest[position.indexToken] -= _sizeDelta;
            }
            
            emit PositionDecreased(_positionKey, _sizeDelta, _collateralDelta, pnl);
        }
        
        // Settle PnL using cached values
        _settlePnL(posAccount, posCollateralToken, pnl, _collateralDelta);
    }
    
    /**
     * @notice Liquidate an underwater position
     * @param _positionKey Position to liquidate
     * @dev KNOWN LIMITATION: Liquidations can be front-run by MEV bots.
     *      This is a common pattern in DeFi protocols (Aave, Compound, GMX).
     *      Mitigation options not implemented due to complexity vs benefit:
     *      - Commit-reveal scheme: Adds latency, poor UX for liquidators
     *      - Private mempool (Flashbots): Requires off-chain infrastructure
     *      - Keeper network: Centralization concerns
     *      The current design incentivizes quick liquidation which benefits protocol health.
     */
    function liquidate(bytes32 _positionKey) external nonReentrant {
        Position storage position = positions[_positionKey];
        if (position.size == 0) revert PositionNotFound();
        
        uint256 currentPrice = priceOracle.getPrice(position.indexToken);
        
        // Check if liquidatable
        (bool isLiquidatable, int256 pnl) = _isLiquidatable(position, currentPrice);
        if (!isLiquidatable) revert NotLiquidatable();
        
        // Calculate liquidation fee and cache all position data BEFORE deletion
        uint256 liquidationFeeAmount = (position.collateral * liquidationFee) / BASIS_POINTS;
        address collateralToken = position.collateralToken;
        uint256 positionCollateral = position.collateral;
        uint256 collateralTokenPrice = priceOracle.getPrice(collateralToken);
        
        // Track bad debt if position is underwater beyond collateral
        int256 remainingCollateral = int256(positionCollateral) + pnl - int256(liquidationFeeAmount);
        if (remainingCollateral < 0) {
            uint256 badDebt = uint256(-remainingCollateral);
            totalBadDebt += badDebt;
            emit BadDebtRecorded(_positionKey, badDebt);
            // Reduce liquidation fee to 0 if bad debt exists
            liquidationFeeAmount = 0;
        }
        
        // Close position (this deletes the position)
        _closePosition(_positionKey, pnl);
        
        // Pay liquidator (using cached values) - MEV protection via on-chain randomness not feasible,
        // but we ensure liquidator gets paid fairly based on the position state
        if (liquidationFeeAmount > 0) {
            vault.transferOut(collateralToken, msg.sender, (liquidationFeeAmount * PRICE_PRECISION) / collateralTokenPrice);
        }
        
        emit PositionLiquidated(_positionKey, msg.sender, pnl);
    }
    
    // ============ Internal Functions ============
    
    function _closePosition(bytes32 _positionKey, int256 _pnl) internal {
        Position storage position = positions[_positionKey];
        
        // Update open interest
        if (position.isLong) {
            longOpenInterest[position.indexToken] -= position.size;
            vault.releaseLiquidity(position.indexToken, (position.size * PRICE_PRECISION) / position.averagePrice);
        } else {
            shortOpenInterest[position.indexToken] -= position.size;
        }
        
        // Clear position
        delete positions[_positionKey];
    }
    
    function _settlePnL(address _account, address _token, int256 _pnl, uint256 _collateralDelta) internal {
        uint256 price = priceOracle.getPrice(_token);
        
        if (_pnl > 0) {
            // Profit: pay from vault
            uint256 payout = _collateralDelta + uint256(_pnl);
            uint256 tokenAmount = (payout * PRICE_PRECISION) / price;
            vault.transferOut(_token, _account, tokenAmount);
        } else {
            // Loss: keep in vault
            uint256 loss = uint256(-_pnl);
            if (_collateralDelta > loss) {
                uint256 payout = _collateralDelta - loss;
                uint256 tokenAmount = (payout * PRICE_PRECISION) / price;
                vault.transferOut(_token, _account, tokenAmount);
            }
        }
    }
    
    function _calculatePnL(Position storage _position, uint256 _currentPrice, uint256 _sizeDelta) internal view returns (int256) {
        if (_position.isLong) {
            if (_currentPrice > _position.averagePrice) {
                return int256((_sizeDelta * (_currentPrice - _position.averagePrice)) / _position.averagePrice);
            } else {
                return -int256((_sizeDelta * (_position.averagePrice - _currentPrice)) / _position.averagePrice);
            }
        } else {
            if (_currentPrice < _position.averagePrice) {
                return int256((_sizeDelta * (_position.averagePrice - _currentPrice)) / _position.averagePrice);
            } else {
                return -int256((_sizeDelta * (_currentPrice - _position.averagePrice)) / _position.averagePrice);
            }
        }
    }
    
    function _calculateFundingPayment(Position storage _position) internal view returns (int256) {
        int256 fundingRate = cumulativeFundingRates[_position.indexToken] - _position.entryFundingRate;
        if (_position.isLong) {
            return (int256(_position.size) * fundingRate) / int256(PRICE_PRECISION);
        } else {
            return -(int256(_position.size) * fundingRate) / int256(PRICE_PRECISION);
        }
    }
    
    function _updateFunding(address _token) internal {
        uint256 timeSinceLast = block.timestamp - lastFundingTimes[_token];
        if (timeSinceLast < FUNDING_INTERVAL) return;
        
        uint256 longOI = longOpenInterest[_token];
        uint256 shortOI = shortOpenInterest[_token];
        
        if (longOI == 0 && shortOI == 0) {
            lastFundingTimes[_token] = block.timestamp;
            return;
        }
        
        // Calculate how many funding periods have passed
        uint256 periods = timeSinceLast / FUNDING_INTERVAL;
        
        // Funding rate based on OI imbalance
        int256 fundingRatePerPeriod;
        if (longOI > shortOI) {
            fundingRatePerPeriod = int256(((longOI - shortOI) * fundingRateFactor) / (longOI + shortOI));
        } else {
            fundingRatePerPeriod = -int256(((shortOI - longOI) * fundingRateFactor) / (longOI + shortOI));
        }
        
        // Apply funding for all passed periods
        int256 totalFunding = fundingRatePerPeriod * int256(periods);
        cumulativeFundingRates[_token] += totalFunding;
        lastFundingTimes[_token] = block.timestamp;
        
        emit FundingUpdated(_token, totalFunding);
    }
    
    function _validatePosition(Position storage _position, uint256 _currentPrice) internal view {
        (bool isLiquidatable,) = _isLiquidatable(_position, _currentPrice);
        if (isLiquidatable) revert InsufficientCollateral();
    }
    
    function _isLiquidatable(Position storage _position, uint256 _currentPrice) internal view returns (bool, int256 pnl) {
        pnl = _calculatePnL(_position, _currentPrice, _position.size);
        int256 fundingPayment = _calculateFundingPayment(_position);
        pnl -= fundingPayment;
        
        int256 remainingCollateral = int256(_position.collateral) + pnl;
        uint256 minCollateral = (_position.size * liquidationThreshold) / BASIS_POINTS;
        
        return (remainingCollateral < int256(minCollateral), pnl);
    }
    
    function _getPositionKey(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _collateralToken, _indexToken, _isLong));
    }
    
    function _getNextAveragePrice(
        uint256 _size,
        uint256 _averagePrice,
        uint256 _sizeDelta,
        uint256 _currentPrice
    ) internal pure returns (uint256) {
        uint256 totalSize = _size + _sizeDelta;
        return ((_size * _averagePrice) + (_sizeDelta * _currentPrice)) / totalSize;
    }
    
    // ============ View Functions ============
    
    function getPosition(bytes32 _positionKey) external view returns (Position memory) {
        return positions[_positionKey];
    }
    
    function getUserPositionKeys(address _user) external view returns (bytes32[] memory) {
        return userPositions[_user];
    }
    
    function getPositionPnL(bytes32 _positionKey) external view returns (int256) {
        Position storage position = positions[_positionKey];
        if (position.size == 0) return 0;
        
        uint256 currentPrice = priceOracle.getPrice(position.indexToken);
        return _calculatePnL(position, currentPrice, position.size);
    }
}
