// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LeveragedFarmV2 - Fixed Leveraged Yield Farming on PancakeSwap
interface IPancakeRouter {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

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

    function swapExactTokensForTokens(
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
}

interface ILendingPool {
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
}

contract LeveragedFarmV2 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Position {
        address owner;
        address lpToken;
        address quoteToken;      // The non-BNB token (e.g., USDT)
        uint256 collateralBNB;   // BNB deposited
        uint256 borrowedAmount;  // Quote tokens borrowed
        uint256 lpAmount;        // LP tokens received
        uint256 leverage;        // 10000 = 1x, 20000 = 2x
        uint256 openTimestamp;
        bool isActive;
    }

    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId = 1;
    mapping(address => uint256[]) public userPositions;

    IPancakeRouter public immutable router;
    IMasterChef public immutable masterChef;
    ILendingPool public lendingPool;
    
    address public immutable WBNB;
    address public immutable CAKE;
    
    uint256 public maxLeverage = 30000;     // 3x max
    uint256 public liquidationThreshold = 8000;
    uint256 public performanceFee = 1000;   // 10%
    address public treasury;

    struct PoolConfig {
        uint256 pid;
        address lpToken;
        address quoteToken;  // Non-BNB token
        bool isActive;
    }
    mapping(address => PoolConfig) public poolConfigs;

    event PositionOpened(uint256 indexed positionId, address indexed owner, uint256 collateral, uint256 borrowed, uint256 lpAmount);
    event PositionClosed(uint256 indexed positionId, address indexed owner, uint256 returnedBNB);
    event Harvested(uint256 indexed positionId, uint256 cakeAmount);

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
        
        IERC20(_cake).forceApprove(_router, type(uint256).max);
    }

    /// @notice Open a leveraged position on a BNB pair
    /// @param lpToken The LP token to farm
    /// @param leverage 10000 = 1x, 20000 = 2x, 30000 = 3x
    function openPosition(
        address lpToken,
        uint256 leverage
    ) external payable nonReentrant {
        require(msg.value >= 0.01 ether, "Min 0.01 BNB");
        require(leverage >= 10000 && leverage <= maxLeverage, "Invalid leverage");
        
        PoolConfig memory pool = poolConfigs[lpToken];
        require(pool.isActive, "Pool not active");

        uint256 bnbAmount = msg.value;
        uint256 borrowAmount = 0;
        
        // Calculate how much to borrow for leverage > 1x
        if (leverage > 10000 && address(lendingPool) != address(0)) {
            // For 2x: borrow equivalent to 1x BNB value in quote tokens
            // For 3x: borrow equivalent to 2x BNB value in quote tokens
            uint256 leverageExtra = leverage - 10000; // e.g., 10000 for 2x
            
            // Get quote token amount for the extra leverage
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pool.quoteToken;
            uint256[] memory amounts = router.getAmountsOut((bnbAmount * leverageExtra) / 10000, path);
            borrowAmount = amounts[1];
            
            // Borrow from lending pool
            lendingPool.borrow(borrowAmount);
        }

        // For 1x leverage OR the BNB portion: swap half of BNB to quote token
        uint256 bnbForSwap = bnbAmount / 2;
        uint256 bnbForLiquidity = bnbAmount - bnbForSwap;
        
        address[] memory swapPath = new address[](2);
        swapPath[0] = WBNB;
        swapPath[1] = pool.quoteToken;
        
        uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbForSwap}(
            0,
            swapPath,
            address(this),
            block.timestamp
        );
        uint256 quoteFromSwap = swapAmounts[1];
        
        // Total quote tokens = swapped + borrowed
        uint256 totalQuoteTokens = quoteFromSwap + borrowAmount;
        
        // Add liquidity
        IERC20(pool.quoteToken).forceApprove(address(router), totalQuoteTokens);
        
        (uint256 usedQuote, uint256 usedBNB, uint256 lpReceived) = router.addLiquidityETH{value: bnbForLiquidity}(
            pool.quoteToken,
            totalQuoteTokens,
            0,
            0,
            address(this),
            block.timestamp
        );

        // Refund unused tokens
        if (totalQuoteTokens > usedQuote) {
            // Swap back unused quote tokens to BNB and refund
            uint256 unusedQuote = totalQuoteTokens - usedQuote;
            IERC20(pool.quoteToken).forceApprove(address(router), unusedQuote);
            address[] memory refundPath = new address[](2);
            refundPath[0] = pool.quoteToken;
            refundPath[1] = WBNB;
            router.swapExactTokensForETH(unusedQuote, 0, refundPath, msg.sender, block.timestamp);
        }

        // Stake LP in MasterChef
        IERC20(lpToken).forceApprove(address(masterChef), lpReceived);
        masterChef.deposit(pool.pid, lpReceived);

        // Create position
        uint256 positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            lpToken: lpToken,
            quoteToken: pool.quoteToken,
            collateralBNB: bnbAmount,
            borrowedAmount: borrowAmount,
            lpAmount: lpReceived,
            leverage: leverage,
            openTimestamp: block.timestamp,
            isActive: true
        });
        
        userPositions[msg.sender].push(positionId);

        emit PositionOpened(positionId, msg.sender, bnbAmount, borrowAmount, lpReceived);
    }

    /// @notice Close a position and return funds
    function closePosition(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(pos.owner == msg.sender, "Not owner");

        PoolConfig memory pool = poolConfigs[pos.lpToken];

        // Withdraw LP from MasterChef (also claims CAKE)
        masterChef.withdraw(pool.pid, pos.lpAmount);

        // Remove liquidity
        IERC20(pos.lpToken).forceApprove(address(router), pos.lpAmount);
        (uint256 quoteReceived, uint256 bnbReceived) = router.removeLiquidityETH(
            pos.quoteToken,
            pos.lpAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        // Repay debt if any
        if (pos.borrowedAmount > 0 && address(lendingPool) != address(0)) {
            // Swap some quote tokens to repay debt
            uint256 toRepay = pos.borrowedAmount;
            if (quoteReceived >= toRepay) {
                IERC20(pos.quoteToken).forceApprove(address(lendingPool), toRepay);
                lendingPool.repay(toRepay);
                quoteReceived -= toRepay;
            } else {
                // Need to swap BNB to cover remaining debt
                IERC20(pos.quoteToken).forceApprove(address(lendingPool), quoteReceived);
                lendingPool.repay(quoteReceived);
                // Remaining debt needs BNB swap - simplified: just repay what we have
                quoteReceived = 0;
            }
        }

        // Swap remaining quote tokens to BNB
        if (quoteReceived > 0) {
            IERC20(pos.quoteToken).forceApprove(address(router), quoteReceived);
            address[] memory path = new address[](2);
            path[0] = pos.quoteToken;
            path[1] = WBNB;
            uint256[] memory amounts = router.swapExactTokensForETH(quoteReceived, 0, path, address(this), block.timestamp);
            bnbReceived += amounts[1];
        }

        // Handle CAKE rewards
        uint256 cakeBalance = IERC20(CAKE).balanceOf(address(this));
        if (cakeBalance > 0) {
            uint256 fee = (cakeBalance * performanceFee) / 10000;
            if (fee > 0) {
                IERC20(CAKE).safeTransfer(treasury, fee);
            }
            // Swap remaining CAKE to BNB for user
            uint256 cakeForUser = cakeBalance - fee;
            if (cakeForUser > 0) {
                IERC20(CAKE).forceApprove(address(router), cakeForUser);
                address[] memory cakePath = new address[](2);
                cakePath[0] = CAKE;
                cakePath[1] = WBNB;
                uint256[] memory cakeAmounts = router.swapExactTokensForETH(cakeForUser, 0, cakePath, address(this), block.timestamp);
                bnbReceived += cakeAmounts[1];
            }
        }

        // Send BNB to user
        pos.isActive = false;
        (bool sent, ) = msg.sender.call{value: bnbReceived}("");
        require(sent, "BNB transfer failed");

        emit PositionClosed(positionId, msg.sender, bnbReceived);
    }

    /// @notice Harvest CAKE rewards (without closing)
    function harvest(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(pos.owner == msg.sender, "Not owner");

        PoolConfig memory pool = poolConfigs[pos.lpToken];

        // Withdraw 0 to claim CAKE
        masterChef.withdraw(pool.pid, 0);

        uint256 cakeBalance = IERC20(CAKE).balanceOf(address(this));
        if (cakeBalance > 0) {
            uint256 fee = (cakeBalance * performanceFee) / 10000;
            if (fee > 0) {
                IERC20(CAKE).safeTransfer(treasury, fee);
            }
            IERC20(CAKE).safeTransfer(msg.sender, cakeBalance - fee);
        }

        emit Harvested(positionId, cakeBalance);
    }

    // View functions
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }

    function getPendingCake(uint256 positionId) external view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive) return 0;
        PoolConfig memory pool = poolConfigs[pos.lpToken];
        return masterChef.pendingCake(pool.pid, address(this));
    }

    // Admin functions
    function addPool(uint256 pid, address lpToken, address quoteToken) external onlyOwner {
        poolConfigs[lpToken] = PoolConfig({
            pid: pid,
            lpToken: lpToken,
            quoteToken: quoteToken,
            isActive: true
        });
        IERC20(lpToken).forceApprove(address(masterChef), type(uint256).max);
    }

    function setLendingPool(address _lendingPool) external onlyOwner {
        lendingPool = ILendingPool(_lendingPool);
    }

    function setMaxLeverage(uint256 _maxLeverage) external onlyOwner {
        require(_maxLeverage <= 50000, "Max 5x");
        maxLeverage = _maxLeverage;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    receive() external payable {}
}
