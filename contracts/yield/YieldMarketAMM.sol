// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YieldMarketAMM
 * @notice AMM for trading PT (Principal Tokens) against underlying
 * @dev Uses a time-decaying curve optimized for yield tokens
 * 
 * Key Concepts:
 * - PT trades at discount to underlying (implied yield)
 * - As maturity approaches, PT → underlying (1:1)
 * - AMM curve accounts for time value
 * 
 * Pricing Model:
 * - Before maturity: PT price = underlying / (1 + impliedRate * timeToMaturity)
 * - At maturity: PT price = underlying (1:1)
 */
contract YieldMarketAMM is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    // ============ State Variables ============
    
    /// @notice Principal Token
    IERC20 public immutable pt;
    
    /// @notice Underlying asset (e.g., USDT)
    IERC20 public immutable underlying;
    
    /// @notice Maturity timestamp
    uint256 public immutable maturity;
    
    /// @notice PT reserves
    uint256 public ptReserve;
    
    /// @notice Underlying reserves
    uint256 public underlyingReserve;
    
    /// @notice Scalar for time-decay curve (affects price sensitivity)
    uint256 public scalar = 100; // 1.00 in basis points
    
    /// @notice Swap fee in basis points (0.1%)
    uint256 public swapFee = 10;
    
    /// @notice Anchor rate - initial implied yield
    uint256 public anchorRate;
    
    /// @notice Fee recipient
    address public feeRecipient;
    
    // ============ Constants ============
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant RATE_PRECISION = 1e18;
    uint256 public constant YEAR = 365 days;
    
    // ============ Events ============
    
    event Swap(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        address indexed tokenOut,
        uint256 amountOut
    );
    event LiquidityAdded(address indexed user, uint256 ptAmount, uint256 underlyingAmount, uint256 lpTokens);
    event LiquidityRemoved(address indexed user, uint256 ptAmount, uint256 underlyingAmount, uint256 lpTokens);
    event ImpliedRateChanged(uint256 oldRate, uint256 newRate);
    
    // ============ Errors ============
    
    error Expired();
    error ZeroAmount();
    error InsufficientOutput();
    error InsufficientLiquidity();
    error InvalidToken();
    
    // ============ Constructor ============
    
    constructor(
        address _pt,
        address _underlying,
        uint256 _maturity,
        uint256 _initialRate,
        address _feeRecipient
    ) ERC20("LEVERAGED PT-LP", "PT-LP") Ownable(msg.sender) {
        pt = IERC20(_pt);
        underlying = IERC20(_underlying);
        maturity = _maturity;
        anchorRate = _initialRate;
        feeRecipient = _feeRecipient;
    }
    
    // ============ Modifiers ============
    
    modifier notExpired() {
        if (block.timestamp >= maturity) revert Expired();
        _;
    }
    
    // ============ Swap Functions ============
    
    /**
     * @notice Swap PT for underlying
     * @param _ptIn Amount of PT to sell
     * @param _minUnderlyingOut Minimum underlying to receive
     */
    function swapPtForUnderlying(
        uint256 _ptIn,
        uint256 _minUnderlyingOut
    ) external nonReentrant notExpired returns (uint256 underlyingOut) {
        if (_ptIn == 0) revert ZeroAmount();
        
        // Calculate output
        underlyingOut = _getUnderlyingOut(_ptIn);
        if (underlyingOut < _minUnderlyingOut) revert InsufficientOutput();
        if (underlyingOut > underlyingReserve) revert InsufficientLiquidity();
        
        // Collect fee
        uint256 fee = (underlyingOut * swapFee) / BASIS_POINTS;
        underlyingOut -= fee;
        
        // Transfer tokens
        pt.safeTransferFrom(msg.sender, address(this), _ptIn);
        underlying.safeTransfer(msg.sender, underlyingOut);
        
        if (fee > 0 && feeRecipient != address(0)) {
            underlying.safeTransfer(feeRecipient, fee);
        }
        
        // Update reserves
        ptReserve += _ptIn;
        underlyingReserve -= underlyingOut + fee;
        
        emit Swap(msg.sender, address(pt), _ptIn, address(underlying), underlyingOut);
    }
    
    /**
     * @notice Swap underlying for PT
     * @param _underlyingIn Amount of underlying to sell
     * @param _minPtOut Minimum PT to receive
     */
    function swapUnderlyingForPt(
        uint256 _underlyingIn,
        uint256 _minPtOut
    ) external nonReentrant notExpired returns (uint256 ptOut) {
        if (_underlyingIn == 0) revert ZeroAmount();
        
        // Collect fee upfront
        uint256 fee = (_underlyingIn * swapFee) / BASIS_POINTS;
        uint256 netIn = _underlyingIn - fee;
        
        // Calculate output
        ptOut = _getPtOut(netIn);
        if (ptOut < _minPtOut) revert InsufficientOutput();
        if (ptOut > ptReserve) revert InsufficientLiquidity();
        
        // Transfer tokens
        underlying.safeTransferFrom(msg.sender, address(this), _underlyingIn);
        pt.safeTransfer(msg.sender, ptOut);
        
        if (fee > 0 && feeRecipient != address(0)) {
            underlying.safeTransfer(feeRecipient, fee);
        }
        
        // Update reserves
        ptReserve -= ptOut;
        underlyingReserve += netIn;
        
        emit Swap(msg.sender, address(underlying), _underlyingIn, address(pt), ptOut);
    }
    
    // ============ Liquidity Functions ============
    
    /**
     * @notice Add liquidity (PT + underlying)
     * @param _ptDesired Desired PT amount
     * @param _underlyingDesired Desired underlying amount
     * @param _minLpTokens Minimum LP tokens to receive
     */
    function addLiquidity(
        uint256 _ptDesired,
        uint256 _underlyingDesired,
        uint256 _minLpTokens
    ) external nonReentrant notExpired returns (uint256 lpTokens, uint256 ptActual, uint256 underlyingActual) {
        if (_ptDesired == 0 || _underlyingDesired == 0) revert ZeroAmount();
        
        uint256 totalSupplyBefore = totalSupply();
        
        if (totalSupplyBefore == 0) {
            // Initial liquidity
            ptActual = _ptDesired;
            underlyingActual = _underlyingDesired;
            lpTokens = _sqrt(ptActual * underlyingActual);
        } else {
            // Proportional liquidity
            uint256 ptRatio = (_ptDesired * RATE_PRECISION) / ptReserve;
            uint256 underlyingRatio = (_underlyingDesired * RATE_PRECISION) / underlyingReserve;
            
            if (ptRatio < underlyingRatio) {
                ptActual = _ptDesired;
                underlyingActual = (ptActual * underlyingReserve) / ptReserve;
            } else {
                underlyingActual = _underlyingDesired;
                ptActual = (underlyingActual * ptReserve) / underlyingReserve;
            }
            
            lpTokens = (totalSupplyBefore * ptActual) / ptReserve;
        }
        
        if (lpTokens < _minLpTokens) revert InsufficientOutput();
        
        // Transfer tokens
        pt.safeTransferFrom(msg.sender, address(this), ptActual);
        underlying.safeTransferFrom(msg.sender, address(this), underlyingActual);
        
        // Update reserves
        ptReserve += ptActual;
        underlyingReserve += underlyingActual;
        
        // Mint LP tokens
        _mint(msg.sender, lpTokens);
        
        emit LiquidityAdded(msg.sender, ptActual, underlyingActual, lpTokens);
    }
    
    /**
     * @notice Remove liquidity
     * @param _lpTokens LP tokens to burn
     * @param _minPtOut Minimum PT to receive
     * @param _minUnderlyingOut Minimum underlying to receive
     */
    function removeLiquidity(
        uint256 _lpTokens,
        uint256 _minPtOut,
        uint256 _minUnderlyingOut
    ) external nonReentrant returns (uint256 ptOut, uint256 underlyingOut) {
        if (_lpTokens == 0) revert ZeroAmount();
        
        uint256 totalSupplyBefore = totalSupply();
        
        // Calculate proportional amounts
        ptOut = (ptReserve * _lpTokens) / totalSupplyBefore;
        underlyingOut = (underlyingReserve * _lpTokens) / totalSupplyBefore;
        
        if (ptOut < _minPtOut || underlyingOut < _minUnderlyingOut) revert InsufficientOutput();
        
        // Burn LP tokens
        _burn(msg.sender, _lpTokens);
        
        // Update reserves
        ptReserve -= ptOut;
        underlyingReserve -= underlyingOut;
        
        // Transfer tokens
        pt.safeTransfer(msg.sender, ptOut);
        underlying.safeTransfer(msg.sender, underlyingOut);
        
        emit LiquidityRemoved(msg.sender, ptOut, underlyingOut, _lpTokens);
    }
    
    // ============ Internal Functions ============
    
    /**
     * @notice Calculate underlying output for PT input
     * @dev Uses time-weighted curve
     */
    function _getUnderlyingOut(uint256 _ptIn) internal view returns (uint256) {
        // Simple constant product with time adjustment
        // As maturity approaches, PT → underlying 1:1
        uint256 timeToMaturity = maturity > block.timestamp ? maturity - block.timestamp : 0;
        uint256 discount = _getDiscount(timeToMaturity);
        
        // Adjusted constant product
        uint256 k = ptReserve * underlyingReserve;
        uint256 newPtReserve = ptReserve + _ptIn;
        uint256 newUnderlyingReserve = k / newPtReserve;
        
        uint256 rawOut = underlyingReserve - newUnderlyingReserve;
        
        // Apply discount (PT worth less than underlying before maturity)
        return (rawOut * discount) / RATE_PRECISION;
    }
    
    /**
     * @notice Calculate PT output for underlying input
     */
    function _getPtOut(uint256 _underlyingIn) internal view returns (uint256) {
        uint256 timeToMaturity = maturity > block.timestamp ? maturity - block.timestamp : 0;
        uint256 discount = _getDiscount(timeToMaturity);
        
        // Adjusted constant product
        uint256 k = ptReserve * underlyingReserve;
        uint256 newUnderlyingReserve = underlyingReserve + _underlyingIn;
        uint256 newPtReserve = k / newUnderlyingReserve;
        
        uint256 rawOut = ptReserve - newPtReserve;
        
        // Apply inverse discount (underlying buys more PT)
        return (rawOut * RATE_PRECISION) / discount;
    }
    
    /**
     * @notice Calculate time-based discount factor
     * @dev Discount = 1 / (1 + rate * timeToMaturity / YEAR)
     */
    function _getDiscount(uint256 _timeToMaturity) internal view returns (uint256) {
        if (_timeToMaturity == 0) return RATE_PRECISION;
        
        uint256 rateAdjustment = (anchorRate * _timeToMaturity) / YEAR;
        return (RATE_PRECISION * RATE_PRECISION) / (RATE_PRECISION + rateAdjustment);
    }
    
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get current implied rate
     */
    function getImpliedRate() external view returns (uint256) {
        if (ptReserve == 0 || underlyingReserve == 0) return anchorRate;
        
        uint256 timeToMaturity = maturity > block.timestamp ? maturity - block.timestamp : 0;
        if (timeToMaturity == 0) return 0;
        
        // Implied rate from PT price
        // Price = underlying / PT in terms of reserves
        // Rate = (1/price - 1) * YEAR / timeToMaturity
        uint256 price = (underlyingReserve * RATE_PRECISION) / ptReserve;
        if (price >= RATE_PRECISION) return 0;
        
        return ((RATE_PRECISION - price) * YEAR * RATE_PRECISION) / (price * timeToMaturity);
    }
    
    /**
     * @notice Get PT price in underlying terms
     */
    function getPtPrice() external view returns (uint256) {
        if (ptReserve == 0) return RATE_PRECISION;
        return (underlyingReserve * RATE_PRECISION) / ptReserve;
    }
    
    /**
     * @notice Quote swap PT → underlying
     */
    function quotePtForUnderlying(uint256 _ptIn) external view returns (uint256) {
        uint256 out = _getUnderlyingOut(_ptIn);
        return out - (out * swapFee) / BASIS_POINTS;
    }
    
    /**
     * @notice Quote swap underlying → PT
     */
    function quoteUnderlyingForPt(uint256 _underlyingIn) external view returns (uint256) {
        uint256 netIn = _underlyingIn - (_underlyingIn * swapFee) / BASIS_POINTS;
        return _getPtOut(netIn);
    }
    
    /**
     * @notice Time until maturity
     */
    function timeToMaturity() external view returns (uint256) {
        return maturity > block.timestamp ? maturity - block.timestamp : 0;
    }
    
    // ============ Admin Functions ============
    
    function setScalar(uint256 _scalar) external onlyOwner {
        scalar = _scalar;
    }
    
    function setSwapFee(uint256 _fee) external onlyOwner {
        require(_fee <= 100, "Fee too high"); // Max 1%
        swapFee = _fee;
    }
    
    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }
}
