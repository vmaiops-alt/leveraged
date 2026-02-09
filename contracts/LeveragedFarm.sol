// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LeveragedFarm - Leveraged Yield Farming on PancakeSwap
/// @notice Deposit collateral, borrow, farm LP with leverage
interface IPancakeRouter {
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

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    
    function WETH() external pure returns (address);
}

interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function totalSupply() external view returns (uint256);
}

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function pendingCake(uint256 _pid, address _user) external view returns (uint256);
    function userInfo(uint256 _pid, address _user) external view returns (uint256 amount, uint256 rewardDebt);
    function poolInfo(uint256 _pid) external view returns (address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accCakePerShare);
}

interface ILendingPool {
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function getBorrowRate() external view returns (uint256);
}

interface IPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

contract LeveragedFarm is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Structs
    struct Position {
        address owner;
        address collateralToken;    // Token used as collateral (e.g., WBNB)
        address borrowToken;        // Token borrowed (e.g., USDT)
        address lpToken;            // PancakeSwap LP token
        uint256 collateralAmount;   // Amount of collateral deposited
        uint256 borrowedAmount;     // Amount borrowed
        uint256 lpAmount;           // Amount of LP tokens
        uint256 leverage;           // Leverage used (10000 = 1x, 20000 = 2x, etc.)
        uint256 openTimestamp;
        bool isActive;
    }

    // State
    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId = 1;
    mapping(address => uint256[]) public userPositions;

    // Config
    IPancakeRouter public immutable router;
    IMasterChef public immutable masterChef;
    ILendingPool public lendingPool;
    IPriceOracle public priceOracle;
    
    address public immutable WBNB;
    address public immutable CAKE;
    
    // Parameters
    uint256 public maxLeverage = 30000;     // 3x max
    uint256 public liquidationThreshold = 8000; // 80% - liquidate if collateral ratio drops below
    uint256 public liquidationBonus = 500;   // 5% bonus for liquidators
    uint256 public performanceFee = 1000;    // 10% of CAKE rewards
    address public treasury;

    // Pool configs (pid => config)
    struct PoolConfig {
        uint256 pid;            // MasterChef pool ID
        address lpToken;
        address token0;
        address token1;
        bool isActive;
    }
    mapping(bytes32 => PoolConfig) public poolConfigs;
    bytes32[] public poolKeys;

    // Events
    event PositionOpened(uint256 indexed positionId, address indexed owner, uint256 collateral, uint256 borrowed, uint256 leverage);
    event PositionClosed(uint256 indexed positionId, address indexed owner, uint256 pnl);
    event PositionLiquidated(uint256 indexed positionId, address indexed liquidator, uint256 bonus);
    event Harvested(uint256 indexed positionId, uint256 cakeAmount, uint256 lpAdded);

    constructor(
        address _router,
        address _masterChef,
        address _cake,
        address _treasury
    ) Ownable(msg.sender) {
        router = IPancakeRouter(_router);
        masterChef = IMasterChef(_masterChef);
        WBNB = router.WETH();
        CAKE = _cake;
        treasury = _treasury;
        
        // Approve CAKE for router (for compounding)
        IERC20(_cake).forceApprove(_router, type(uint256).max);
    }

    /// @notice Open a leveraged farming position
    /// @param borrowToken Token to borrow
    /// @param lpToken LP token to farm
    /// @param leverage Leverage amount (10000 = 1x, 20000 = 2x, 30000 = 3x)
    function openPosition(
        address borrowToken,
        address lpToken,
        uint256 leverage
    ) external payable nonReentrant {
        require(msg.value > 0, "Must deposit BNB as collateral");
        require(leverage >= 10000 && leverage <= maxLeverage, "Invalid leverage");
        
        bytes32 poolKey = keccak256(abi.encodePacked(lpToken));
        PoolConfig memory pool = poolConfigs[poolKey];
        require(pool.isActive, "Pool not active");

        uint256 collateralValue = msg.value; // In BNB
        uint256 borrowAmount = (collateralValue * (leverage - 10000)) / 10000;
        
        // Borrow from lending pool
        if (borrowAmount > 0) {
            lendingPool.borrow(borrowAmount);
        }

        // Add liquidity
        uint256 lpReceived;
        if (pool.token0 == WBNB || pool.token1 == WBNB) {
            // BNB pair
            address otherToken = pool.token0 == WBNB ? pool.token1 : pool.token0;
            
            // Swap half of borrowed tokens for BNB if needed, or use BNB collateral
            IERC20(borrowToken).forceApprove(address(router), borrowAmount);
            
            (, , lpReceived) = router.addLiquidityETH{value: msg.value}(
                otherToken,
                borrowAmount,
                0,
                0,
                address(this),
                block.timestamp
            );
        } else {
            // Token-Token pair - swap BNB to tokens first
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pool.token0;
            
            uint256[] memory amounts = router.swapExactETHForTokens{value: msg.value / 2}(
                0,
                path,
                address(this),
                block.timestamp
            );
            
            path[1] = pool.token1;
            uint256[] memory amounts2 = router.swapExactETHForTokens{value: msg.value / 2}(
                0,
                path,
                address(this),
                block.timestamp
            );
            
            IERC20(pool.token0).forceApprove(address(router), amounts[1]);
            IERC20(pool.token1).forceApprove(address(router), amounts2[1]);
            
            (, , lpReceived) = router.addLiquidity(
                pool.token0,
                pool.token1,
                amounts[1],
                amounts2[1],
                0,
                0,
                address(this),
                block.timestamp
            );
        }

        // Stake LP in MasterChef
        IERC20(lpToken).forceApprove(address(masterChef), lpReceived);
        masterChef.deposit(pool.pid, lpReceived);

        // Create position
        uint256 positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            collateralToken: WBNB,
            borrowToken: borrowToken,
            lpToken: lpToken,
            collateralAmount: msg.value,
            borrowedAmount: borrowAmount,
            lpAmount: lpReceived,
            leverage: leverage,
            openTimestamp: block.timestamp,
            isActive: true
        });
        
        userPositions[msg.sender].push(positionId);

        emit PositionOpened(positionId, msg.sender, msg.value, borrowAmount, leverage);
    }

    /// @notice Close a leveraged position
    function closePosition(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(pos.owner == msg.sender, "Not position owner");

        _closePosition(positionId, pos.owner);
    }

    /// @notice Liquidate an unhealthy position
    function liquidate(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(getHealthFactor(positionId) < liquidationThreshold, "Position is healthy");

        uint256 bonus = (pos.collateralAmount * liquidationBonus) / 10000;
        _closePosition(positionId, msg.sender);
        
        // Send liquidation bonus
        (bool sent, ) = msg.sender.call{value: bonus}("");
        require(sent, "Bonus transfer failed");

        emit PositionLiquidated(positionId, msg.sender, bonus);
    }

    /// @notice Harvest CAKE rewards and compound into more LP
    function harvest(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");

        bytes32 poolKey = keccak256(abi.encodePacked(pos.lpToken));
        PoolConfig memory pool = poolConfigs[poolKey];

        // Withdraw 0 to claim pending CAKE
        masterChef.withdraw(pool.pid, 0);
        
        uint256 cakeBalance = IERC20(CAKE).balanceOf(address(this));
        if (cakeBalance == 0) return;

        // Take performance fee
        uint256 fee = (cakeBalance * performanceFee) / 10000;
        if (fee > 0) {
            IERC20(CAKE).safeTransfer(treasury, fee);
            cakeBalance -= fee;
        }

        // Swap CAKE to LP tokens
        // First swap half to token0, half to token1
        uint256 halfCake = cakeBalance / 2;
        
        address[] memory path = new address[](3);
        path[0] = CAKE;
        path[1] = WBNB;
        path[2] = pool.token0;
        
        IERC20(CAKE).forceApprove(address(router), cakeBalance);
        uint256[] memory amounts0 = router.swapExactTokensForTokens(halfCake, 0, path, address(this), block.timestamp);
        
        path[2] = pool.token1;
        uint256[] memory amounts1 = router.swapExactTokensForTokens(halfCake, 0, path, address(this), block.timestamp);

        // Add liquidity
        IERC20(pool.token0).forceApprove(address(router), amounts0[2]);
        IERC20(pool.token1).forceApprove(address(router), amounts1[2]);
        
        (, , uint256 lpAdded) = router.addLiquidity(
            pool.token0,
            pool.token1,
            amounts0[2],
            amounts1[2],
            0,
            0,
            address(this),
            block.timestamp
        );

        // Stake new LP
        IERC20(pos.lpToken).forceApprove(address(masterChef), lpAdded);
        masterChef.deposit(pool.pid, lpAdded);
        
        pos.lpAmount += lpAdded;

        emit Harvested(positionId, cakeBalance + fee, lpAdded);
    }

    /// @notice Get position health factor (10000 = 100% healthy)
    function getHealthFactor(uint256 positionId) public view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.borrowedAmount == 0) return 10000;

        // Get LP value
        uint256 lpValue = getLpValue(pos.lpToken, pos.lpAmount);
        
        // Health = (LP Value / Debt) * 10000
        return (lpValue * 10000) / pos.borrowedAmount;
    }

    /// @notice Get LP token value in borrow token terms
    function getLpValue(address lpToken, uint256 amount) public view returns (uint256) {
        IPancakePair pair = IPancakePair(lpToken);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();
        
        // Simplified: assume both tokens have similar value
        // In production, use oracle for accurate pricing
        uint256 token0Amount = (uint256(reserve0) * amount) / totalSupply;
        uint256 token1Amount = (uint256(reserve1) * amount) / totalSupply;
        
        return token0Amount + token1Amount;
    }

    /// @notice Get pending CAKE rewards
    function pendingRewards(uint256 positionId) external view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive) return 0;
        
        bytes32 poolKey = keccak256(abi.encodePacked(pos.lpToken));
        PoolConfig memory pool = poolConfigs[poolKey];
        
        return masterChef.pendingCake(pool.pid, address(this));
    }

    /// @notice Get user's positions
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }

    // Internal functions
    function _closePosition(uint256 positionId, address recipient) internal {
        Position storage pos = positions[positionId];
        
        bytes32 poolKey = keccak256(abi.encodePacked(pos.lpToken));
        PoolConfig memory pool = poolConfigs[poolKey];

        // Withdraw LP from MasterChef
        masterChef.withdraw(pool.pid, pos.lpAmount);

        // Remove liquidity
        IERC20(pos.lpToken).forceApprove(address(router), pos.lpAmount);
        
        uint256 bnbReceived;
        uint256 tokenReceived;
        
        if (pool.token0 == WBNB || pool.token1 == WBNB) {
            address otherToken = pool.token0 == WBNB ? pool.token1 : pool.token0;
            (tokenReceived, bnbReceived) = router.removeLiquidityETH(
                otherToken,
                pos.lpAmount,
                0,
                0,
                address(this),
                block.timestamp
            );
            
            // Swap tokens back to BNB
            if (tokenReceived > 0) {
                address[] memory path = new address[](2);
                path[0] = otherToken;
                path[1] = WBNB;
                IERC20(otherToken).forceApprove(address(router), tokenReceived);
                uint256[] memory amounts = router.swapExactTokensForETH(tokenReceived, 0, path, address(this), block.timestamp);
                bnbReceived += amounts[1];
            }
        } else {
            (uint256 amount0, uint256 amount1) = router.removeLiquidity(
                pool.token0,
                pool.token1,
                pos.lpAmount,
                0,
                0,
                address(this),
                block.timestamp
            );
            
            // Swap both to BNB
            address[] memory path = new address[](2);
            path[1] = WBNB;
            
            path[0] = pool.token0;
            IERC20(pool.token0).forceApprove(address(router), amount0);
            uint256[] memory amounts0 = router.swapExactTokensForETH(amount0, 0, path, address(this), block.timestamp);
            
            path[0] = pool.token1;
            IERC20(pool.token1).forceApprove(address(router), amount1);
            uint256[] memory amounts1 = router.swapExactTokensForETH(amount1, 0, path, address(this), block.timestamp);
            
            bnbReceived = amounts0[1] + amounts1[1];
        }

        // Repay debt
        if (pos.borrowedAmount > 0) {
            // Swap BNB to borrow token for repayment
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pos.borrowToken;
            
            uint256 repayAmount = pos.borrowedAmount; // + interest (simplified)
            uint256[] memory amounts = router.swapExactETHForTokens{value: bnbReceived / 2}(
                repayAmount,
                path,
                address(this),
                block.timestamp
            );
            
            IERC20(pos.borrowToken).forceApprove(address(lendingPool), amounts[1]);
            lendingPool.repay(amounts[1]);
            
            bnbReceived -= bnbReceived / 2;
        }

        // Send remaining BNB to recipient
        if (bnbReceived > 0) {
            (bool sent, ) = recipient.call{value: bnbReceived}("");
            require(sent, "BNB transfer failed");
        }

        // Mark position as closed
        pos.isActive = false;

        emit PositionClosed(positionId, pos.owner, bnbReceived);
    }

    // Admin functions
    function addPool(uint256 pid, address lpToken) external onlyOwner {
        IPancakePair pair = IPancakePair(lpToken);
        address token0 = pair.token0();
        address token1 = pair.token1();
        
        bytes32 poolKey = keccak256(abi.encodePacked(lpToken));
        poolConfigs[poolKey] = PoolConfig({
            pid: pid,
            lpToken: lpToken,
            token0: token0,
            token1: token1,
            isActive: true
        });
        poolKeys.push(poolKey);
        
        // Approve LP for MasterChef
        IERC20(lpToken).forceApprove(address(masterChef), type(uint256).max);
    }

    function setLendingPool(address _lendingPool) external onlyOwner {
        lendingPool = ILendingPool(_lendingPool);
    }

    function setPriceOracle(address _oracle) external onlyOwner {
        priceOracle = IPriceOracle(_oracle);
    }

    function setMaxLeverage(uint256 _maxLeverage) external onlyOwner {
        require(_maxLeverage <= 50000, "Max 5x");
        maxLeverage = _maxLeverage;
    }

    function setLiquidationParams(uint256 _threshold, uint256 _bonus) external onlyOwner {
        liquidationThreshold = _threshold;
        liquidationBonus = _bonus;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    // Receive BNB
    receive() external payable {}
}
