// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LeveragedFarmV4 - Fixed Liquidity Ratio
/// @notice Leveraged yield farming with proper BNB/USDT ratio calculation

interface IPancakeRouter {
    function addLiquidityETH(
        address token, uint256 amountTokenDesired, uint256 amountTokenMin,
        uint256 amountETHMin, address to, uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function removeLiquidityETH(
        address token, uint256 liquidity, uint256 amountTokenMin,
        uint256 amountETHMin, address to, uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactETHForTokens(
        uint256 amountOutMin, address[] calldata path, address to, uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline
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
    function coverBadDebt(uint256 amount) external;
}

contract LeveragedFarmV4 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Position {
        address owner;
        address lpToken;
        address quoteToken;
        uint256 collateralBNB;
        uint256 borrowedAmount;
        uint256 lpAmount;
        uint256 leverage;
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
    
    uint256 public constant PRECISION = 10000;
    uint256 public maxLeverage = 30000;
    uint256 public liquidationThreshold = 11000;
    uint256 public liquidationBonus = 500;
    uint256 public performanceFee = 1000;
    
    address public treasury;
    address public insuranceFund;
    
    struct PoolConfig {
        uint256 pid;
        address lpToken;
        address quoteToken;
        bool isActive;
    }
    mapping(address => PoolConfig) public poolConfigs;

    event PositionOpened(uint256 indexed positionId, address indexed owner, uint256 collateral, uint256 borrowed, uint256 lpAmount, uint256 leverage);
    event PositionClosed(uint256 indexed positionId, address indexed owner, uint256 returnedBNB);
    event PositionLiquidated(uint256 indexed positionId, address indexed liquidator, address indexed owner, uint256 badDebt, uint256 liquidatorReward);
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
        insuranceFund = _treasury;
        
        IERC20(_cake).forceApprove(_router, type(uint256).max);
    }

    // ============ View Functions ============

    function getHealthFactor(uint256 positionId) public view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.borrowedAmount == 0) return type(uint256).max;
        
        uint256 positionValue = getPositionValue(positionId);
        uint256 debtValue = pos.borrowedAmount;
        
        if (debtValue == 0) return type(uint256).max;
        return (positionValue * PRECISION) / debtValue;
    }

    function getPositionValue(uint256 positionId) public view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.lpAmount == 0) return 0;
        
        IPancakePair pair = IPancakePair(pos.lpToken);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();
        
        if (totalSupply == 0) return 0;
        
        uint256 share0 = (uint256(reserve0) * pos.lpAmount) / totalSupply;
        uint256 share1 = (uint256(reserve1) * pos.lpAmount) / totalSupply;
        
        address token0 = pair.token0();
        if (token0 == pos.quoteToken) {
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pos.quoteToken;
            uint256[] memory amounts = router.getAmountsOut(share1, path);
            return share0 + amounts[1];
        } else {
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pos.quoteToken;
            uint256[] memory amounts = router.getAmountsOut(share0, path);
            return share1 + amounts[1];
        }
    }

    function canLiquidate(uint256 positionId) public view returns (bool) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.borrowedAmount == 0) return false;
        
        uint256 healthFactor = getHealthFactor(positionId);
        return healthFactor < liquidationThreshold;
    }

    function getPendingCake(uint256 positionId) external view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive) return 0;
        PoolConfig memory pool = poolConfigs[pos.lpToken];
        return masterChef.pendingCake(pool.pid, address(this));
    }

    // ============ User Functions ============

    /// @notice Open a leveraged position with FIXED ratio calculation
    function openPosition(address lpToken, uint256 leverage) external payable nonReentrant {
        require(msg.value >= 0.01 ether, "Min 0.01 BNB");
        require(leverage >= 10000 && leverage <= maxLeverage, "Invalid leverage");
        
        PoolConfig memory pool = poolConfigs[lpToken];
        require(pool.isActive, "Pool not active");

        uint256 bnbAmount = msg.value;
        uint256 borrowAmount = 0;
        
        // Calculate borrow amount for leverage
        if (leverage > 10000 && address(lendingPool) != address(0)) {
            uint256 leverageExtra = leverage - 10000;
            
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pool.quoteToken;
            uint256[] memory amounts = router.getAmountsOut((bnbAmount * leverageExtra) / 10000, path);
            borrowAmount = amounts[1];
            
            lendingPool.borrow(borrowAmount);
        }

        // === FIXED: Proper ratio calculation ===
        // Get current pool ratio
        IPancakePair pair = IPancakePair(lpToken);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        address token0 = pair.token0();
        
        uint256 reserveQuote;
        uint256 reserveBNB;
        if (token0 == pool.quoteToken) {
            reserveQuote = uint256(reserve0);
            reserveBNB = uint256(reserve1);
        } else {
            reserveQuote = uint256(reserve1);
            reserveBNB = uint256(reserve0);
        }
        
        // Calculate BNB value in quote tokens
        address[] memory pricePath = new address[](2);
        pricePath[0] = WBNB;
        pricePath[1] = pool.quoteToken;
        uint256[] memory bnbValue = router.getAmountsOut(bnbAmount, pricePath);
        uint256 totalValueInQuote = bnbValue[1] + borrowAmount;
        
        // For LP, we need 50% in quote tokens and 50% in BNB (by value)
        // Target quote amount = totalValue / 2
        uint256 targetQuoteAmount = totalValueInQuote / 2;
        
        // We have: borrowAmount in quote tokens
        // We need: targetQuoteAmount in quote tokens
        // If borrowAmount < targetQuoteAmount, swap some BNB to quote
        // If borrowAmount > targetQuoteAmount, swap some quote to BNB
        
        uint256 quoteForLiquidity;
        uint256 bnbForLiquidity;
        
        if (borrowAmount < targetQuoteAmount) {
            // Need more quote tokens - swap BNB for the difference
            uint256 quoteNeeded = targetQuoteAmount - borrowAmount;
            
            // Calculate how much BNB to swap
            address[] memory swapPath = new address[](2);
            swapPath[0] = WBNB;
            swapPath[1] = pool.quoteToken;
            
            // Binary search for optimal BNB amount (simplified: use ratio)
            uint256 bnbToSwap = (bnbAmount * quoteNeeded) / bnbValue[1];
            if (bnbToSwap > bnbAmount) bnbToSwap = bnbAmount * 95 / 100; // Cap at 95%
            
            uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbToSwap}(
                0, swapPath, address(this), block.timestamp
            );
            
            quoteForLiquidity = borrowAmount + swapAmounts[1];
            bnbForLiquidity = bnbAmount - bnbToSwap;
        } else {
            // Have excess quote tokens - swap some to BNB
            uint256 quoteExcess = borrowAmount - targetQuoteAmount;
            
            IERC20(pool.quoteToken).forceApprove(address(router), quoteExcess);
            
            address[] memory swapPath = new address[](2);
            swapPath[0] = pool.quoteToken;
            swapPath[1] = WBNB;
            
            uint256[] memory swapAmounts = router.swapExactTokensForETH(
                quoteExcess, 0, swapPath, address(this), block.timestamp
            );
            
            quoteForLiquidity = borrowAmount - quoteExcess;
            bnbForLiquidity = bnbAmount + swapAmounts[1];
        }
        
        // Add liquidity with proper amounts
        IERC20(pool.quoteToken).forceApprove(address(router), quoteForLiquidity);
        
        (uint256 usedQuote, uint256 usedBNB, uint256 lpReceived) = router.addLiquidityETH{value: bnbForLiquidity}(
            pool.quoteToken, quoteForLiquidity, 0, 0, address(this), block.timestamp
        );
        
        // Handle any leftover tokens (return to user as BNB)
        uint256 leftoverQuote = quoteForLiquidity - usedQuote;
        uint256 leftoverBNB = bnbForLiquidity - usedBNB;
        
        if (leftoverQuote > 1000) { // Min dust threshold
            IERC20(pool.quoteToken).forceApprove(address(router), leftoverQuote);
            address[] memory returnPath = new address[](2);
            returnPath[0] = pool.quoteToken;
            returnPath[1] = WBNB;
            try router.swapExactTokensForETH(leftoverQuote, 0, returnPath, msg.sender, block.timestamp) {} catch {}
        }
        
        if (leftoverBNB > 0) {
            (bool sent,) = msg.sender.call{value: leftoverBNB}("");
            // Don't revert on failure, just continue
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

        emit PositionOpened(positionId, msg.sender, bnbAmount, borrowAmount, lpReceived, leverage);
    }

    function closePosition(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(pos.owner == msg.sender, "Not owner");

        _closePosition(positionId, pos.owner, false, address(0));
    }

    function liquidate(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(canLiquidate(positionId), "Position healthy");
        require(msg.sender != pos.owner, "Cannot liquidate own position");

        _closePosition(positionId, pos.owner, true, msg.sender);
    }

    function harvest(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(pos.owner == msg.sender, "Not owner");

        PoolConfig memory pool = poolConfigs[pos.lpToken];
        
        // Withdraw and redeposit to claim CAKE
        masterChef.withdraw(pool.pid, 0);
        
        uint256 cakeBalance = IERC20(CAKE).balanceOf(address(this));
        if (cakeBalance > 0) {
            uint256 fee = (cakeBalance * performanceFee) / PRECISION;
            uint256 userAmount = cakeBalance - fee;
            
            if (fee > 0) {
                IERC20(CAKE).safeTransfer(treasury, fee);
            }
            if (userAmount > 0) {
                IERC20(CAKE).safeTransfer(msg.sender, userAmount);
            }
            
            emit Harvested(positionId, userAmount);
        }
    }

    // ============ Internal Functions ============

    function _closePosition(
        uint256 positionId, 
        address owner, 
        bool isLiquidation, 
        address liquidator
    ) internal {
        Position storage pos = positions[positionId];
        PoolConfig memory pool = poolConfigs[pos.lpToken];

        masterChef.withdraw(pool.pid, pos.lpAmount);

        IERC20(pos.lpToken).forceApprove(address(router), pos.lpAmount);
        (uint256 quoteReceived, uint256 bnbReceived) = router.removeLiquidityETH(
            pos.quoteToken, pos.lpAmount, 0, 0, address(this), block.timestamp
        );

        uint256 badDebt = 0;
        uint256 liquidatorReward = 0;
        uint256 returnToBorrower = 0;

        if (pos.borrowedAmount > 0 && address(lendingPool) != address(0)) {
            uint256 toRepay = pos.borrowedAmount;
            
            if (quoteReceived >= toRepay) {
                IERC20(pos.quoteToken).forceApprove(address(lendingPool), toRepay);
                lendingPool.repay(toRepay);
                quoteReceived -= toRepay;
                
                if (quoteReceived > 0) {
                    IERC20(pos.quoteToken).forceApprove(address(router), quoteReceived);
                    address[] memory path = new address[](2);
                    path[0] = pos.quoteToken;
                    path[1] = WBNB;
                    uint256[] memory amounts = router.swapExactTokensForETH(
                        quoteReceived, 0, path, address(this), block.timestamp
                    );
                    bnbReceived += amounts[1];
                }
            } else {
                if (quoteReceived > 0) {
                    IERC20(pos.quoteToken).forceApprove(address(lendingPool), quoteReceived);
                    lendingPool.repay(quoteReceived);
                }
                badDebt = toRepay - quoteReceived;
                
                if (bnbReceived > 0 && badDebt > 0) {
                    address[] memory path = new address[](2);
                    path[0] = WBNB;
                    path[1] = pos.quoteToken;
                    uint256[] memory neededAmounts = router.getAmountsOut(bnbReceived, path);
                    
                    if (neededAmounts[1] >= badDebt) {
                        uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbReceived}(
                            0, path, address(this), block.timestamp
                        );
                        IERC20(pos.quoteToken).forceApprove(address(lendingPool), badDebt);
                        lendingPool.repay(badDebt);
                        
                        uint256 excess = swapAmounts[1] - badDebt;
                        if (excess > 0) {
                            IERC20(pos.quoteToken).forceApprove(address(router), excess);
                            address[] memory returnPath = new address[](2);
                            returnPath[0] = pos.quoteToken;
                            returnPath[1] = WBNB;
                            uint256[] memory returnAmounts = router.swapExactTokensForETH(
                                excess, 0, returnPath, address(this), block.timestamp
                            );
                            bnbReceived = returnAmounts[1];
                        } else {
                            bnbReceived = 0;
                        }
                        badDebt = 0;
                    } else {
                        uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbReceived}(
                            0, path, address(this), block.timestamp
                        );
                        IERC20(pos.quoteToken).forceApprove(address(lendingPool), swapAmounts[1]);
                        lendingPool.repay(swapAmounts[1]);
                        badDebt -= swapAmounts[1];
                        bnbReceived = 0;
                    }
                }
                
                if (badDebt > 0) {
                    lendingPool.coverBadDebt(badDebt);
                }
                
                quoteReceived = 0;
            }
        }

        if (isLiquidation && bnbReceived > 0) {
            liquidatorReward = (bnbReceived * liquidationBonus) / PRECISION;
            bnbReceived -= liquidatorReward;
            
            (bool sent,) = liquidator.call{value: liquidatorReward}("");
            require(sent, "Failed to send liquidator reward");
        }

        pos.isActive = false;
        returnToBorrower = bnbReceived;

        if (returnToBorrower > 0) {
            (bool sent,) = owner.call{value: returnToBorrower}("");
            require(sent, "Failed to send BNB");
        }

        if (isLiquidation) {
            emit PositionLiquidated(positionId, liquidator, owner, badDebt, liquidatorReward);
        } else {
            emit PositionClosed(positionId, owner, returnToBorrower);
        }
    }

    // ============ Admin Functions ============

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

    function setLiquidationParams(uint256 _threshold, uint256 _bonus) external onlyOwner {
        require(_threshold >= 10000 && _threshold <= 15000, "Invalid threshold");
        require(_bonus <= 1000, "Bonus too high");
        liquidationThreshold = _threshold;
        liquidationBonus = _bonus;
    }

    function setInsuranceFund(address _fund) external onlyOwner {
        insuranceFund = _fund;
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    receive() external payable {}
}
