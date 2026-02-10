// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PrincipalToken.sol";
import "./YieldToken.sol";

/**
 * @title YieldTokenizer
 * @notice Splits yield-bearing assets into Principal (PT) and Yield (YT) tokens
 * @dev Core Pendle-style yield tokenization contract
 * 
 * Flow:
 * 1. User deposits underlying (e.g., aUSDT)
 * 2. Receives PT + YT at 1:1 ratio
 * 3. PT represents principal, redeemable at maturity
 * 4. YT represents yield rights until maturity
 * 5. Can redeem PT+YT back to underlying anytime
 * 6. At maturity: PT redeemable 1:1, YT expires worthless
 */
contract YieldTokenizer is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    // ============ Structs ============
    
    struct Market {
        address underlying;         // Yield-bearing asset (e.g., aUSDT)
        address principalToken;     // PT address
        address yieldToken;         // YT address
        uint256 maturity;           // Maturity timestamp
        uint256 totalDeposited;     // Total underlying deposited
        uint256 lastYieldIndex;     // Last recorded yield index
        bool active;                // Market active flag
    }
    
    // ============ State Variables ============
    
    /// @notice All markets by ID
    mapping(bytes32 => Market) public markets;
    
    /// @notice List of all market IDs
    bytes32[] public marketIds;
    
    /// @notice Protocol fee in basis points (e.g., 100 = 1%)
    uint256 public protocolFee = 100;
    
    /// @notice Fee recipient
    address public feeRecipient;
    
    /// @notice Minimum maturity duration
    uint256 public constant MIN_MATURITY = 7 days;
    
    /// @notice Maximum maturity duration
    uint256 public constant MAX_MATURITY = 5 * 365 days;
    
    // ============ Events ============
    
    event MarketCreated(bytes32 indexed marketId, address underlying, address pt, address yt, uint256 maturity);
    event Deposited(bytes32 indexed marketId, address indexed user, uint256 amount, uint256 ptMinted, uint256 ytMinted);
    event Redeemed(bytes32 indexed marketId, address indexed user, uint256 ptBurned, uint256 ytBurned, uint256 underlying);
    event MaturityRedeemed(bytes32 indexed marketId, address indexed user, uint256 ptBurned, uint256 underlying);
    event YieldHarvested(bytes32 indexed marketId, uint256 yieldAmount);
    event BadDebt(bytes32 indexed marketId, address indexed user, uint256 shortfall);
    
    // ============ Errors ============
    
    error MarketExists();
    error MarketNotFound();
    error MarketNotActive();
    error InvalidMaturity();
    error ZeroAmount();
    error InsufficientBalance();
    error NotMatured();
    error AlreadyMatured();
    
    // ============ Constructor ============
    
    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }
    
    // ============ Market Creation ============
    
    /**
     * @notice Create a new PT/YT market for an underlying asset
     * @param _underlying Yield-bearing asset address
     * @param _maturity Maturity timestamp
     * @return marketId The created market ID
     */
    function createMarket(
        address _underlying,
        uint256 _maturity
    ) external onlyOwner returns (bytes32 marketId) {
        // Validate maturity
        if (_maturity <= block.timestamp + MIN_MATURITY) revert InvalidMaturity();
        if (_maturity > block.timestamp + MAX_MATURITY) revert InvalidMaturity();
        
        // Generate market ID
        marketId = keccak256(abi.encodePacked(_underlying, _maturity));
        if (markets[marketId].active) revert MarketExists();
        
        // Get underlying token info
        string memory underlyingSymbol = _getSymbol(_underlying);
        string memory maturityStr = _formatDate(_maturity);
        
        // Create PT token
        string memory ptName = string(abi.encodePacked("PT-", underlyingSymbol, "-", maturityStr));
        string memory ptSymbol = string(abi.encodePacked("PT-", underlyingSymbol));
        PrincipalToken pt = new PrincipalToken(ptName, ptSymbol, _underlying, _maturity, address(this));
        
        // Create YT token
        string memory ytName = string(abi.encodePacked("YT-", underlyingSymbol, "-", maturityStr));
        string memory ytSymbol = string(abi.encodePacked("YT-", underlyingSymbol));
        YieldToken yt = new YieldToken(ytName, ytSymbol, _underlying, _maturity, address(this));
        
        // Store market
        markets[marketId] = Market({
            underlying: _underlying,
            principalToken: address(pt),
            yieldToken: address(yt),
            maturity: _maturity,
            totalDeposited: 0,
            lastYieldIndex: _getYieldIndex(_underlying),
            active: true
        });
        
        marketIds.push(marketId);
        
        emit MarketCreated(marketId, _underlying, address(pt), address(yt), _maturity);
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Deposit underlying and receive PT + YT
     * @param _marketId Market ID
     * @param _amount Amount of underlying to deposit
     */
    function deposit(bytes32 _marketId, uint256 _amount, uint256 _minPtAmount) external nonReentrant returns (uint256 ptAmount, uint256 ytAmount) {
        if (_amount == 0) revert ZeroAmount();
        
        Market storage market = markets[_marketId];
        if (!market.active) revert MarketNotFound();
        if (block.timestamp >= market.maturity) revert AlreadyMatured();
        
        // Harvest any pending yield first
        _harvestYield(_marketId);
        
        // Transfer underlying from user
        IERC20(market.underlying).safeTransferFrom(msg.sender, address(this), _amount);
        
        // Calculate fees
        uint256 feeAmount = (_amount * protocolFee) / 10000;
        uint256 netAmount = _amount - feeAmount;
        
        // Transfer fee
        if (feeAmount > 0 && feeRecipient != address(0)) {
            IERC20(market.underlying).safeTransfer(feeRecipient, feeAmount);
        }
        
        // Mint PT and YT 1:1
        ptAmount = netAmount;
        ytAmount = netAmount;
        
        // Slippage protection
        require(ptAmount >= _minPtAmount, "Slippage: insufficient PT output");
        
        PrincipalToken(market.principalToken).mint(msg.sender, ptAmount);
        YieldToken(market.yieldToken).mint(msg.sender, ytAmount);
        
        market.totalDeposited += netAmount;
        
        emit Deposited(_marketId, msg.sender, _amount, ptAmount, ytAmount);
    }
    
    /**
     * @notice Deposit underlying and receive PT + YT (no slippage protection)
     * @dev Convenience function for backwards compatibility
     */
    function deposit(bytes32 _marketId, uint256 _amount) external nonReentrant returns (uint256 ptAmount, uint256 ytAmount) {
        return this.deposit(_marketId, _amount, 0);
    }
    
    /**
     * @notice Redeem PT + YT back to underlying (before maturity)
     * @param _marketId Market ID
     * @param _amount Amount of PT/YT to redeem (must have equal amounts)
     */
    function redeem(bytes32 _marketId, uint256 _amount) external nonReentrant returns (uint256 underlyingAmount) {
        if (_amount == 0) revert ZeroAmount();
        
        Market storage market = markets[_marketId];
        if (!market.active) revert MarketNotFound();
        
        // Verify user has enough PT and YT
        if (IERC20(market.principalToken).balanceOf(msg.sender) < _amount) revert InsufficientBalance();
        if (IERC20(market.yieldToken).balanceOf(msg.sender) < _amount) revert InsufficientBalance();
        
        // Harvest any pending yield first
        _harvestYield(_marketId);
        
        // Burn PT and YT
        PrincipalToken(market.principalToken).burn(msg.sender, _amount);
        YieldToken(market.yieldToken).burn(msg.sender, _amount);
        
        // Return underlying 1:1
        underlyingAmount = _amount;
        market.totalDeposited -= underlyingAmount;
        
        IERC20(market.underlying).safeTransfer(msg.sender, underlyingAmount);
        
        emit Redeemed(_marketId, msg.sender, _amount, _amount, underlyingAmount);
    }
    
    /**
     * @notice Redeem PT at maturity (YT not required)
     * @param _marketId Market ID
     * @param _amount Amount of PT to redeem
     */
    function redeemAtMaturity(bytes32 _marketId, uint256 _amount) external nonReentrant returns (uint256 underlyingAmount) {
        if (_amount == 0) revert ZeroAmount();
        
        Market storage market = markets[_marketId];
        if (!market.active) revert MarketNotFound();
        if (block.timestamp < market.maturity) revert NotMatured();
        
        // Verify user has enough PT
        if (IERC20(market.principalToken).balanceOf(msg.sender) < _amount) revert InsufficientBalance();
        
        // Burn PT
        PrincipalToken(market.principalToken).burn(msg.sender, _amount);
        
        // Return underlying 1:1
        underlyingAmount = _amount;
        
        // Check for bad debt scenario
        if (market.totalDeposited < underlyingAmount) {
            // Bad debt exists - user receives less than expected
            uint256 shortfall = underlyingAmount - market.totalDeposited;
            underlyingAmount = market.totalDeposited;
            market.totalDeposited = 0;
            emit BadDebt(_marketId, msg.sender, shortfall);
        } else {
            market.totalDeposited -= underlyingAmount;
        }
        
        IERC20(market.underlying).safeTransfer(msg.sender, underlyingAmount);
        
        emit MaturityRedeemed(_marketId, msg.sender, _amount, underlyingAmount);
    }
    
    // ============ Yield Functions ============
    
    /**
     * @notice Harvest yield and distribute to YT holders
     */
    function harvestYield(bytes32 _marketId) external {
        _harvestYield(_marketId);
    }
    
    function _harvestYield(bytes32 _marketId) internal {
        Market storage market = markets[_marketId];
        if (block.timestamp >= market.maturity) return;
        
        uint256 currentIndex = _getYieldIndex(market.underlying);
        if (currentIndex <= market.lastYieldIndex) return;
        
        // Calculate yield accrued
        uint256 yieldAmount = (market.totalDeposited * (currentIndex - market.lastYieldIndex)) / 1e18;
        
        if (yieldAmount > 0) {
            // Distribute to YT holders
            YieldToken(market.yieldToken).distributeYield(yieldAmount);
            market.lastYieldIndex = currentIndex;
            
            emit YieldHarvested(_marketId, yieldAmount);
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get market info
     */
    function getMarket(bytes32 _marketId) external view returns (
        address underlying,
        address principalToken,
        address yieldToken,
        uint256 maturity,
        uint256 totalDeposited,
        bool active
    ) {
        Market storage market = markets[_marketId];
        return (
            market.underlying,
            market.principalToken,
            market.yieldToken,
            market.maturity,
            market.totalDeposited,
            market.active
        );
    }
    
    /**
     * @notice Get number of markets
     */
    function getMarketCount() external view returns (uint256) {
        return marketIds.length;
    }
    
    // ============ Internal Helpers ============
    
    function _getSymbol(address _token) internal view returns (string memory) {
        // Try to get symbol, fallback to "TOKEN" if not available
        (bool success, bytes memory data) = _token.staticcall(abi.encodeWithSignature("symbol()"));
        if (success && data.length > 0) {
            return abi.decode(data, (string));
        }
        return "TOKEN";
    }
    
    function _formatDate(uint256 _timestamp) internal pure returns (string memory) {
        // Simplified date format (would use proper date lib in production)
        return "MATURITY";
    }
    
    // Yield index adapters for different protocols
    mapping(address => address) public yieldAdapters;
    
    function setYieldAdapter(address _underlying, address _adapter) external onlyOwner {
        yieldAdapters[_underlying] = _adapter;
    }
    
    function _getYieldIndex(address _underlying) internal view returns (uint256) {
        address adapter = yieldAdapters[_underlying];
        if (adapter != address(0)) {
            // Call adapter to get yield index
            // Adapter should implement: function getYieldIndex() external view returns (uint256)
            (bool success, bytes memory data) = adapter.staticcall(
                abi.encodeWithSignature("getYieldIndex()")
            );
            if (success && data.length >= 32) {
                return abi.decode(data, (uint256));
            }
        }
        // Default: 1e18 (no yield if no adapter configured)
        return 1e18;
    }
    
    // ============ Admin Functions ============
    
    function setProtocolFee(uint256 _fee) external onlyOwner {
        require(_fee <= 500, "Fee too high"); // Max 5%
        protocolFee = _fee;
    }
    
    function setFeeRecipient(address _recipient) external onlyOwner {
        feeRecipient = _recipient;
    }
    
    function deactivateMarket(bytes32 _marketId) external onlyOwner {
        markets[_marketId].active = false;
    }
}

// Using IERC20Metadata from OpenZeppelin via ERC20
