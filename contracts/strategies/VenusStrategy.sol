// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./BaseStrategy.sol";

interface IVToken {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function supplyRatePerBlock() external view returns (uint256);
}

interface IComptroller {
    function claimVenus(address holder) external;
    function claimVenus(address holder, address[] memory vTokens) external;
    function venusAccrued(address holder) external view returns (uint256);
}

interface IVenusRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

/**
 * @title VenusStrategy
 * @notice Yield strategy for Venus Protocol lending
 * @dev Supplies assets to Venus and earns interest + XVS rewards
 */
contract VenusStrategy is BaseStrategy {
    
    // ============ State ============
    
    IVToken public vToken;          // Venus vToken (e.g., vUSDT)
    IComptroller public comptroller;
    IVenusRouter public router;
    address public xvs;             // XVS token
    address public wbnb;
    
    uint256 public totalDeposited;
    uint256 public lastHarvest;
    
    // ============ Constants ============
    
    uint256 public constant HARVEST_INTERVAL = 1 hours;
    uint256 public constant BLOCKS_PER_YEAR = 10512000; // BSC ~3s blocks
    uint256 public constant BPS = 10000;
    uint256 public constant MIN_SLIPPAGE_BPS = 50; // 0.5% minimum slippage tolerance
    
    /// @notice Slippage tolerance for swaps in BPS (default 1%)
    uint256 public slippageTolerance = 100;
    
    // ============ Constructor ============
    
    constructor(
        address _asset,      // Underlying (e.g., USDT)
        address _vToken,     // Venus vToken
        address _comptroller,
        address _router,
        address _xvs,
        address _wbnb
    ) BaseStrategy(_asset) {
        vToken = IVToken(_vToken);
        comptroller = IComptroller(_comptroller);
        router = IVenusRouter(_router);
        xvs = _xvs;
        wbnb = _wbnb;
    }
    
    // ============ Strategy Functions ============
    
    /**
     * @notice Deposit assets into Venus
     * @param amount Amount of underlying asset
     * @return shares Shares received
     */
    function deposit(uint256 amount) external override onlyVault whenNotPaused returns (uint256 shares) {
        require(amount > 0, "Zero amount");
        
        // Transfer underlying from vault
        _transferIn(asset, msg.sender, amount);
        
        // Calculate shares based on current value
        uint256 totalValue = getTVL();
        if (totalShares == 0 || totalValue == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalValue;
        }
        
        // Approve and mint vTokens
        _approve(asset, address(vToken), amount);
        uint256 mintResult = vToken.mint(amount);
        require(mintResult == 0, "Mint failed");
        
        // Update state
        totalShares += shares;
        userShares[msg.sender] += shares;
        totalDeposited += amount;
        
        emit Deposited(msg.sender, amount, shares);
    }
    
    /**
     * @notice Withdraw assets from Venus
     * @param shares Shares to withdraw
     * @return amount Amount of underlying received
     */
    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        require(shares > 0, "Zero shares");
        require(userShares[msg.sender] >= shares, "Insufficient shares");
        
        // Calculate amount based on current value
        amount = (shares * getTVL()) / totalShares;
        
        // Redeem from Venus
        uint256 redeemResult = vToken.redeemUnderlying(amount);
        require(redeemResult == 0, "Redeem failed");
        
        // Update state
        totalShares -= shares;
        userShares[msg.sender] -= shares;
        totalDeposited = totalDeposited > amount ? totalDeposited - amount : 0;
        
        // Transfer underlying to vault
        _transferOut(asset, msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, shares);
    }
    
    /**
     * @notice Harvest XVS rewards and compound
     * @return harvested Value harvested and reinvested
     */
    function harvest() external override returns (uint256 harvested) {
        require(block.timestamp >= lastHarvest + HARVEST_INTERVAL, "Too soon");
        
        // Claim XVS rewards
        address[] memory vTokens = new address[](1);
        vTokens[0] = address(vToken);
        comptroller.claimVenus(address(this), vTokens);
        
        uint256 xvsBalance = _balanceOf(xvs);
        if (xvsBalance == 0) return 0;
        
        // Swap XVS -> underlying asset
        _approve(xvs, address(router), xvsBalance);
        
        address[] memory path;
        if (asset == wbnb) {
            path = new address[](2);
            path[0] = xvs;
            path[1] = wbnb;
        } else {
            path = new address[](3);
            path[0] = xvs;
            path[1] = wbnb;
            path[2] = asset;
        }
        
        // Calculate minimum output with slippage protection
        uint256[] memory expectedAmounts = router.getAmountsOut(xvsBalance, path);
        uint256 expectedOut = expectedAmounts[expectedAmounts.length - 1];
        uint256 minAmountOut = (expectedOut * (BPS - slippageTolerance)) / BPS;
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            xvsBalance,
            minAmountOut, // Slippage protected
            path,
            address(this),
            block.timestamp
        );
        
        harvested = amounts[amounts.length - 1];
        
        // Reinvest
        if (harvested > 0) {
            _approve(asset, address(vToken), harvested);
            vToken.mint(harvested);
            totalDeposited += harvested;
        }
        
        lastHarvest = block.timestamp;
        emit Harvested(harvested);
    }
    
    /**
     * @notice Set slippage tolerance (owner only)
     * @param _slippageTolerance Slippage tolerance in BPS (min 0.5%, max 5%)
     */
    function setSlippageTolerance(uint256 _slippageTolerance) external onlyOwner {
        require(_slippageTolerance >= MIN_SLIPPAGE_BPS, "Slippage too low");
        require(_slippageTolerance <= 500, "Slippage too high"); // Max 5%
        slippageTolerance = _slippageTolerance;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get current APY
     * @return apy APY in BPS
     */
    function getAPY() external view override returns (uint256 apy) {
        // Get supply rate per block
        uint256 supplyRate = vToken.supplyRatePerBlock();
        
        // Annualize: APY = (1 + rate)^blocks_per_year - 1
        // Simplified: APY ≈ rate * blocks_per_year
        apy = (supplyRate * BLOCKS_PER_YEAR * BPS) / 1e18;
        
        // Note: This doesn't include XVS rewards
        // In production, add XVS APY component
    }
    
    /**
     * @notice Get total value locked
     * @return tvl Total value in underlying asset
     */
    function getTVL() public view override returns (uint256 tvl) {
        uint256 vTokenBalance = vToken.balanceOf(address(this));
        uint256 exchangeRate = vToken.exchangeRateStored();
        
        // vToken balance * exchange rate / 1e18
        tvl = (vTokenBalance * exchangeRate) / 1e18;
    }
    
    /**
     * @notice Get user's value
     * @param user User address
     * @return value User's underlying value
     */
    function getUserValue(address user) external view override returns (uint256 value) {
        if (totalShares == 0) return 0;
        return (userShares[user] * getTVL()) / totalShares;
    }
    
    /**
     * @notice Get pending XVS rewards
     * @return pending Pending XVS
     */
    function pendingRewards() public view override returns (uint256) {
        return comptroller.venusAccrued(address(this));
    }
    
    // ============ Emergency ============
    
    /**
     * @notice Emergency redeem all vTokens
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 vTokenBalance = vToken.balanceOf(address(this));
        if (vTokenBalance > 0) {
            vToken.redeem(vTokenBalance);
        }
        // Underlying stays in contract for users to claim
    }
}
