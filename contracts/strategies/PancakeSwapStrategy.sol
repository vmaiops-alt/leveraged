// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./BaseStrategy.sol";

/**
 * @title PancakeSwapStrategy
 * @notice Yield strategy for PancakeSwap LP farming
 * @dev Deposits LP tokens into MasterChef to earn CAKE
 */
contract PancakeSwapStrategy is BaseStrategy {
    
    // ============ PancakeSwap Interfaces ============
    
    interface IMasterChef {
        function deposit(uint256 pid, uint256 amount) external;
        function withdraw(uint256 pid, uint256 amount) external;
        function pendingCake(uint256 pid, address user) external view returns (uint256);
        function userInfo(uint256 pid, address user) external view returns (uint256 amount, uint256 rewardDebt);
        function poolInfo(uint256 pid) external view returns (address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accCakePerShare);
    }
    
    interface IRouter {
        function swapExactTokensForTokens(
            uint256 amountIn,
            uint256 amountOutMin,
            address[] calldata path,
            address to,
            uint256 deadline
        ) external returns (uint256[] memory amounts);
        
        function addLiquidity(
            address tokenA,
            address tokenB,
            uint256 amountADesired,
            uint256 amountBDesired,
            uint256 amountAMin,
            uint256 amountBMin,
            address to,
            uint256 deadline
        ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    }
    
    // ============ State ============
    
    IMasterChef public masterChef;
    IRouter public router;
    address public cake;        // CAKE token
    address public wbnb;        // WBNB for swaps
    uint256 public pid;         // Pool ID in MasterChef
    
    address public tokenA;      // LP token A
    address public tokenB;      // LP token B
    
    uint256 public totalDeposited;
    uint256 public lastHarvest;
    
    // ============ Constants ============
    
    uint256 public constant HARVEST_INTERVAL = 1 hours;
    uint256 public constant SLIPPAGE_BPS = 50; // 0.5% slippage tolerance
    uint256 public constant BPS = 10000;
    
    // ============ Constructor ============
    
    constructor(
        address _lpToken,
        address _masterChef,
        address _router,
        address _cake,
        address _wbnb,
        uint256 _pid,
        address _tokenA,
        address _tokenB
    ) BaseStrategy(_lpToken) {
        masterChef = IMasterChef(_masterChef);
        router = IRouter(_router);
        cake = _cake;
        wbnb = _wbnb;
        pid = _pid;
        tokenA = _tokenA;
        tokenB = _tokenB;
    }
    
    // ============ Strategy Functions ============
    
    /**
     * @notice Deposit LP tokens into MasterChef
     * @param amount Amount of LP tokens
     * @return shares Shares received
     */
    function deposit(uint256 amount) external override onlyVault whenNotPaused returns (uint256 shares) {
        require(amount > 0, "Zero amount");
        
        // Transfer LP tokens from vault
        _transferIn(asset, msg.sender, amount);
        
        // Calculate shares
        uint256 totalValue = getTVL();
        if (totalShares == 0 || totalValue == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalValue;
        }
        
        // Approve and deposit to MasterChef
        _approve(asset, address(masterChef), amount);
        masterChef.deposit(pid, amount);
        
        // Update state
        totalShares += shares;
        userShares[msg.sender] += shares;
        totalDeposited += amount;
        
        emit Deposited(msg.sender, amount, shares);
    }
    
    /**
     * @notice Withdraw LP tokens from MasterChef
     * @param shares Shares to withdraw
     * @return amount Amount of LP tokens received
     */
    function withdraw(uint256 shares) external override onlyVault returns (uint256 amount) {
        require(shares > 0, "Zero shares");
        require(userShares[msg.sender] >= shares, "Insufficient shares");
        
        // Calculate amount
        amount = (shares * getTVL()) / totalShares;
        
        // Withdraw from MasterChef
        masterChef.withdraw(pid, amount);
        
        // Update state
        totalShares -= shares;
        userShares[msg.sender] -= shares;
        totalDeposited = totalDeposited > amount ? totalDeposited - amount : 0;
        
        // Transfer LP tokens to vault
        _transferOut(asset, msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount, shares);
    }
    
    /**
     * @notice Harvest CAKE rewards and compound
     * @return harvested Amount of value harvested
     */
    function harvest() external override returns (uint256 harvested) {
        require(block.timestamp >= lastHarvest + HARVEST_INTERVAL, "Too soon");
        
        // Claim CAKE rewards (deposit 0 triggers claim)
        masterChef.deposit(pid, 0);
        
        uint256 cakeBalance = _balanceOf(cake);
        if (cakeBalance == 0) return 0;
        
        // Swap half to tokenA, half to tokenB
        uint256 halfCake = cakeBalance / 2;
        
        // Swap CAKE -> tokenA
        _approve(cake, address(router), cakeBalance);
        address[] memory pathA = new address[](3);
        pathA[0] = cake;
        pathA[1] = wbnb;
        pathA[2] = tokenA;
        
        uint256[] memory amountsA = router.swapExactTokensForTokens(
            halfCake,
            0, // Accept any amount (should add slippage protection)
            pathA,
            address(this),
            block.timestamp
        );
        
        // Swap CAKE -> tokenB
        address[] memory pathB = new address[](3);
        pathB[0] = cake;
        pathB[1] = wbnb;
        pathB[2] = tokenB;
        
        uint256[] memory amountsB = router.swapExactTokensForTokens(
            halfCake,
            0,
            pathB,
            address(this),
            block.timestamp
        );
        
        // Add liquidity
        uint256 amountA = _balanceOf(tokenA);
        uint256 amountB = _balanceOf(tokenB);
        
        _approve(tokenA, address(router), amountA);
        _approve(tokenB, address(router), amountB);
        
        (,, uint256 lpReceived) = router.addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            0,
            0,
            address(this),
            block.timestamp
        );
        
        // Deposit new LP tokens
        _approve(asset, address(masterChef), lpReceived);
        masterChef.deposit(pid, lpReceived);
        
        totalDeposited += lpReceived;
        lastHarvest = block.timestamp;
        harvested = lpReceived;
        
        emit Harvested(harvested);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get current APY estimate
     * @return apy APY in BPS
     */
    function getAPY() external view override returns (uint256 apy) {
        // Simplified APY calculation
        // In production, use actual reward rate and prices
        uint256 pending = pendingRewards();
        if (totalDeposited == 0) return 0;
        
        // Annualize based on pending rewards
        // This is a rough estimate
        uint256 hourlyRate = (pending * BPS) / totalDeposited;
        apy = hourlyRate * 24 * 365;
    }
    
    /**
     * @notice Get total value locked
     * @return tvl Total LP tokens in strategy
     */
    function getTVL() public view override returns (uint256 tvl) {
        (uint256 deposited,) = masterChef.userInfo(pid, address(this));
        return deposited;
    }
    
    /**
     * @notice Get user's value
     * @param user User address
     * @return value User's LP token value
     */
    function getUserValue(address user) external view override returns (uint256 value) {
        if (totalShares == 0) return 0;
        return (userShares[user] * getTVL()) / totalShares;
    }
    
    /**
     * @notice Get pending CAKE rewards
     * @return pending Pending CAKE
     */
    function pendingRewards() public view override returns (uint256) {
        return masterChef.pendingCake(pid, address(this));
    }
    
    // ============ Emergency ============
    
    /**
     * @notice Emergency withdraw without caring about rewards
     */
    function emergencyWithdraw() external onlyOwner {
        masterChef.withdraw(pid, getTVL());
        // LP tokens stay in contract for users to claim
    }
}
