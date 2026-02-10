// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PerpVault
 * @notice GMX-style multi-asset liquidity vault for perpetual trading
 * @dev LPs deposit assets, receive vault tokens, act as counterparty to traders
 * 
 * GMX GLP Model:
 * - Vault holds basket of assets (BTC, ETH, stables)
 * - Traders open longs/shorts against the vault
 * - When traders lose, LPs profit
 * - When traders win, LPs pay out
 * - LPs earn trading fees + funding rates
 * 
 * Risk/Reward for LPs:
 * - Earn: 70% of trading fees
 * - Earn: Funding rate surplus
 * - Risk: Trader profits come from LP capital
 */
contract PerpVault is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    // ============ Structs ============
    
    struct Asset {
        address token;              // Token address
        uint256 weight;             // Target weight in basis points (10000 = 100%)
        uint256 minProfit;          // Min profit for swaps in bps
        uint256 maxAmount;          // Max amount that can be held
        bool isStable;              // Is stablecoin
        bool isShortable;           // Can be shorted
        uint256 totalDeposited;     // Total deposited
        uint256 reserved;           // Reserved for positions
    }
    
    // ============ State Variables ============
    
    /// @notice Supported assets
    mapping(address => Asset) public assets;
    
    /// @notice List of asset addresses
    address[] public assetList;
    
    /// @notice Position manager contract
    address public positionManager;
    
    /// @notice Price oracle
    address public priceOracle;
    
    /// @notice Total value locked (in USD, 30 decimals)
    uint256 public totalAUM;
    
    /// @notice Fee configuration
    uint256 public mintFee = 30;        // 0.3%
    uint256 public burnFee = 30;        // 0.3%
    uint256 public marginFee = 10;      // 0.1%
    
    /// @notice Fee distribution
    uint256 public lpFeeShare = 7000;   // 70% to LPs
    
    /// @notice Accumulated fees for distribution
    uint256 public accumulatedFees;
    
    /// @notice Fee per vault token (scaled by 1e18)
    uint256 public feePerToken;
    
    /// @notice User's fee per token at last interaction
    mapping(address => uint256) public userFeePerToken;
    
    /// @notice Unclaimed fees per user
    mapping(address => uint256) public unclaimedFees;
    
    // ============ Constants ============
    
    uint256 public constant PRICE_PRECISION = 1e30;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant USD_DECIMALS = 30;
    
    // ============ Events ============
    
    event AssetAdded(address indexed token, uint256 weight);
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 vaultTokens);
    event Withdraw(address indexed user, address indexed token, uint256 vaultTokens, uint256 amount);
    event FeesCollected(uint256 amount);
    event FeesClaimed(address indexed user, uint256 amount);
    event ReserveUpdated(address indexed token, uint256 newReserve);
    
    // ============ Errors ============
    
    error AssetNotSupported();
    error AssetAlreadyExists();
    error InsufficientLiquidity();
    error MaxCapacityReached();
    error OnlyPositionManager();
    error ZeroAmount();
    error InvalidWeight();
    
    // ============ Modifiers ============
    
    modifier onlyPositionManager() {
        if (msg.sender != positionManager) revert OnlyPositionManager();
        _;
    }
    
    modifier updateFees(address _user) {
        _updateUserFees(_user);
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _priceOracle
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        priceOracle = _priceOracle;
    }
    
    // ============ LP Functions ============
    
    /**
     * @notice Deposit asset and receive vault tokens
     * @param _token Asset to deposit
     * @param _amount Amount to deposit
     * @param _minVaultTokens Minimum vault tokens to receive
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint256 _minVaultTokens
    ) external nonReentrant updateFees(msg.sender) returns (uint256 vaultTokens) {
        if (_amount == 0) revert ZeroAmount();
        
        Asset storage asset = assets[_token];
        if (asset.token == address(0)) revert AssetNotSupported();
        if (asset.totalDeposited + _amount > asset.maxAmount) revert MaxCapacityReached();
        
        // Transfer tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        // Calculate vault tokens to mint
        uint256 price = _getPrice(_token);
        uint256 usdValue = (_amount * price) / PRICE_PRECISION;
        
        // Mint fee
        uint256 fee = (usdValue * mintFee) / BASIS_POINTS;
        usdValue -= fee;
        _collectFees(fee);
        
        if (totalSupply() == 0) {
            vaultTokens = usdValue;
        } else {
            require(totalAUM > 0, "Invalid AUM state");
            vaultTokens = (usdValue * totalSupply()) / totalAUM;
        }
        
        require(vaultTokens > 0, "Deposit too small - zero tokens would be minted");
        require(vaultTokens >= _minVaultTokens, "Slippage");
        
        asset.totalDeposited += _amount;
        totalAUM += usdValue;
        
        _mint(msg.sender, vaultTokens);
        
        emit Deposit(msg.sender, _token, _amount, vaultTokens);
    }
    
    /**
     * @notice Withdraw asset by burning vault tokens
     * @param _token Asset to receive
     * @param _vaultTokens Vault tokens to burn
     * @param _minAmount Minimum asset amount to receive
     */
    function withdraw(
        address _token,
        uint256 _vaultTokens,
        uint256 _minAmount
    ) external nonReentrant updateFees(msg.sender) returns (uint256 amount) {
        if (_vaultTokens == 0) revert ZeroAmount();
        
        Asset storage asset = assets[_token];
        if (asset.token == address(0)) revert AssetNotSupported();
        
        // Calculate USD value of vault tokens
        uint256 usdValue = (_vaultTokens * totalAUM) / totalSupply();
        
        // Burn fee
        uint256 fee = (usdValue * burnFee) / BASIS_POINTS;
        usdValue -= fee;
        _collectFees(fee);
        
        // Calculate token amount
        uint256 price = _getPrice(_token);
        amount = (usdValue * PRICE_PRECISION) / price;
        
        // Check liquidity (not reserved)
        uint256 available = asset.totalDeposited - asset.reserved;
        if (amount > available) revert InsufficientLiquidity();
        
        require(amount >= _minAmount, "Slippage");
        
        asset.totalDeposited -= amount;
        totalAUM -= usdValue;
        
        _burn(msg.sender, _vaultTokens);
        IERC20(_token).safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, _token, _vaultTokens, amount);
    }
    
    /**
     * @notice Claim accumulated trading fees
     */
    function claimFees() external updateFees(msg.sender) returns (uint256 amount) {
        uint256 feeUsd = unclaimedFees[msg.sender];
        if (feeUsd == 0) return 0;
        
        unclaimedFees[msg.sender] = 0;
        
        // Pay in stablecoin (first stable in list)
        // Convert from USD (30 decimals) to token decimals (typically 18)
        address stableToken = _getStableToken();
        uint256 stablePrice = _getPrice(stableToken);
        amount = (feeUsd * 1e18) / stablePrice; // Convert USD to token amount
        
        IERC20(stableToken).safeTransfer(msg.sender, amount);
        
        emit FeesClaimed(msg.sender, amount);
    }
    
    // ============ Position Manager Functions ============
    
    /**
     * @notice Reserve liquidity for a position
     * @param _token Token to reserve
     * @param _amount Amount to reserve
     */
    function reserveLiquidity(address _token, uint256 _amount) external onlyPositionManager {
        Asset storage asset = assets[_token];
        uint256 available = asset.totalDeposited - asset.reserved;
        if (_amount > available) revert InsufficientLiquidity();
        
        asset.reserved += _amount;
        emit ReserveUpdated(_token, asset.reserved);
    }
    
    /**
     * @notice Release reserved liquidity
     */
    function releaseLiquidity(address _token, uint256 _amount) external onlyPositionManager {
        Asset storage asset = assets[_token];
        asset.reserved = asset.reserved > _amount ? asset.reserved - _amount : 0;
        emit ReserveUpdated(_token, asset.reserved);
    }
    
    /**
     * @notice Transfer tokens to position manager for PnL settlement
     */
    function transferOut(address _token, address _to, uint256 _amount) external onlyPositionManager {
        Asset storage asset = assets[_token];
        if (_amount > asset.totalDeposited) revert InsufficientLiquidity();
        
        asset.totalDeposited -= _amount;
        IERC20(_token).safeTransfer(_to, _amount);
    }
    
    /**
     * @notice Receive tokens from position manager
     */
    function transferIn(address _token, uint256 _amount) external onlyPositionManager {
        Asset storage asset = assets[_token];
        asset.totalDeposited += _amount;
    }
    
    /**
     * @notice Collect trading fees
     */
    function collectTradingFees(uint256 _usdAmount) external onlyPositionManager {
        _collectFees(_usdAmount);
    }
    
    // ============ Internal Functions ============
    
    function _collectFees(uint256 _usdAmount) internal {
        if (_usdAmount == 0) return;
        
        uint256 lpShare = (_usdAmount * lpFeeShare) / BASIS_POINTS;
        
        uint256 supply = totalSupply();
        if (supply > 0) {
            feePerToken += (lpShare * 1e18) / supply;
        }
        
        accumulatedFees += _usdAmount;
        emit FeesCollected(_usdAmount);
    }
    
    function _updateUserFees(address _user) internal {
        if (_user == address(0)) return;
        
        uint256 balance = balanceOf(_user);
        if (balance > 0) {
            uint256 pending = (balance * (feePerToken - userFeePerToken[_user])) / 1e18;
            unclaimedFees[_user] += pending;
        }
        userFeePerToken[_user] = feePerToken;
    }
    
    function _update(address from, address to, uint256 value) internal virtual override {
        _updateUserFees(from);
        _updateUserFees(to);
        super._update(from, to, value);
    }
    
    function _getPrice(address _token) internal view returns (uint256) {
        // Mock price - in production, query oracle
        if (assets[_token].isStable) return PRICE_PRECISION;
        return 2000 * PRICE_PRECISION; // Mock ETH price
    }
    
    function _getStableToken() internal view returns (address) {
        for (uint i = 0; i < assetList.length; i++) {
            if (assets[assetList[i]].isStable) {
                return assetList[i];
            }
        }
        return assetList[0];
    }
    
    // ============ View Functions ============
    
    function getAUM() external view returns (uint256) {
        return totalAUM;
    }
    
    function getVaultTokenPrice() external view returns (uint256) {
        if (totalSupply() == 0) return PRICE_PRECISION;
        return (totalAUM * PRICE_PRECISION) / totalSupply();
    }
    
    function getAvailableLiquidity(address _token) external view returns (uint256) {
        Asset storage asset = assets[_token];
        return asset.totalDeposited - asset.reserved;
    }
    
    function pendingFees(address _user) external view returns (uint256) {
        uint256 balance = balanceOf(_user);
        uint256 pending = (balance * (feePerToken - userFeePerToken[_user])) / 1e18;
        return unclaimedFees[_user] + pending;
    }
    
    // ============ Admin Functions ============
    
    function addAsset(
        address _token,
        uint256 _weight,
        uint256 _minProfit,
        uint256 _maxAmount,
        bool _isStable,
        bool _isShortable
    ) external onlyOwner {
        if (assets[_token].token != address(0)) revert AssetAlreadyExists();
        if (_weight > BASIS_POINTS) revert InvalidWeight();
        
        assets[_token] = Asset({
            token: _token,
            weight: _weight,
            minProfit: _minProfit,
            maxAmount: _maxAmount,
            isStable: _isStable,
            isShortable: _isShortable,
            totalDeposited: 0,
            reserved: 0
        });
        
        assetList.push(_token);
        emit AssetAdded(_token, _weight);
    }
    
    function setPositionManager(address _positionManager) external onlyOwner {
        positionManager = _positionManager;
    }
    
    function setFees(uint256 _mintFee, uint256 _burnFee, uint256 _marginFee) external onlyOwner {
        require(_mintFee <= 100 && _burnFee <= 100 && _marginFee <= 100, "Fee too high");
        mintFee = _mintFee;
        burnFee = _burnFee;
        marginFee = _marginFee;
    }
}
