// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LeveragedFarmV6 - Complete Fee System with Staking Integration
/// @notice Leveraged yield farming with comprehensive fees and LVG staking benefits
/// @dev Integrates with LVGStaking for fee reductions

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
}

interface ILendingPool {
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function coverBadDebt(uint256 amount) external;
}

interface ILVGStaking {
    function getFeeReduction(address user) external view returns (uint256);
    function getUserTier(address user) external view returns (uint256);
}

contract LeveragedFarmV6 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ============ Structs ============
    
    struct Position {
        address owner;
        address lpToken;
        address quoteToken;
        uint256 collateralBNB;
        uint256 borrowedAmount;
        uint256 lpAmount;
        uint256 leverage;
        uint256 openTimestamp;
        uint256 entryBnbPrice;      // BNB price at entry (in quote token, 18 decimals)
        bool isActive;
    }

    struct PoolConfig {
        uint256 pid;
        address lpToken;
        address quoteToken;
        bool isActive;
    }

    struct FeeConfig {
        uint256 openFeeBps;           // Fee on position open (default 10 = 0.1%)
        uint256 closeFeeBps;          // Fee on position close (default 10 = 0.1%)
        uint256 performanceFeeBps;    // Fee on CAKE rewards (default 1000 = 10%)
        uint256 priceApprecFeeBps;    // Fee on BNB price gains (default 2500 = 25%)
        uint256 liquidationFeeBps;    // Fee to treasury on liquidation (default 100 = 1%)
    }

    // ============ State Variables ============
    
    mapping(uint256 => Position) public positions;
    uint256 public nextPositionId = 1;
    mapping(address => uint256[]) public userPositions;
    mapping(address => PoolConfig) public poolConfigs;

    IPancakeRouter public immutable router;
    IMasterChef public immutable masterChef;
    ILendingPool public lendingPool;
    ILVGStaking public lvgStaking;
    
    address public immutable WBNB;
    address public immutable CAKE;
    
    // Fee configuration
    FeeConfig public fees;
    uint256 public constant BPS = 10000;
    
    // Risk parameters
    uint256 public maxLeverage = 30000;              // 3x default, can be higher for stakers
    uint256 public liquidationThreshold = 11000;     // 110%
    uint256 public liquidationBonus = 500;           // 5% to liquidator
    
    address public treasury;
    
    // Tier-based max leverage
    mapping(uint256 => uint256) public tierMaxLeverage;

    // ============ Events ============
    
    event PositionOpened(uint256 indexed positionId, address indexed owner, uint256 collateral, uint256 borrowed, uint256 lpAmount, uint256 leverage, uint256 entryPrice);
    event PositionClosed(uint256 indexed positionId, address indexed owner, uint256 returnedBNB, uint256 feesCollected);
    event PositionLiquidated(uint256 indexed positionId, address indexed liquidator, address indexed owner, uint256 badDebt, uint256 liquidatorReward, uint256 treasuryFee);
    event Harvested(uint256 indexed positionId, uint256 cakeAmount, uint256 feeAmount);
    event FeesUpdated(uint256 openFee, uint256 closeFee, uint256 perfFee, uint256 priceFee, uint256 liqFee);
    event TokensRescued(address token, uint256 amount);

    // ============ Constructor ============
    
    constructor(
        address _router,
        address _masterChef,
        address _cake,
        address _treasury,
        address _lvgStaking
    ) Ownable(msg.sender) {
        router = IPancakeRouter(_router);
        masterChef = IMasterChef(_masterChef);
        WBNB = router.WETH();
        CAKE = _cake;
        treasury = _treasury;
        lvgStaking = ILVGStaking(_lvgStaking);
        
        // Default fees
        fees = FeeConfig({
            openFeeBps: 10,         // 0.1%
            closeFeeBps: 10,        // 0.1%
            performanceFeeBps: 1000, // 10%
            priceApprecFeeBps: 2500, // 25%
            liquidationFeeBps: 100   // 1%
        });
        
        // Tier-based max leverage (tier => max leverage in BPS)
        tierMaxLeverage[0] = 30000;  // No tier: 3x
        tierMaxLeverage[1] = 30000;  // Bronze: 3x
        tierMaxLeverage[2] = 40000;  // Silver: 4x
        tierMaxLeverage[3] = 40000;  // Gold: 4x
        tierMaxLeverage[4] = 50000;  // Diamond: 5x
        
        IERC20(_cake).forceApprove(_router, type(uint256).max);
    }

    // ============ View Functions ============

    /// @notice Get user's effective fee after staking reduction
    function getEffectiveFee(address user, uint256 baseFee) public view returns (uint256) {
        if (address(lvgStaking) == address(0)) return baseFee;
        
        uint256 reduction = lvgStaking.getFeeReduction(user);
        if (reduction >= BPS) return 0;
        
        return (baseFee * (BPS - reduction)) / BPS;
    }

    /// @notice Get user's max leverage based on staking tier
    function getUserMaxLeverage(address user) public view returns (uint256) {
        if (address(lvgStaking) == address(0)) return maxLeverage;
        
        uint256 tier = lvgStaking.getUserTier(user);
        uint256 tierLeverage = tierMaxLeverage[tier];
        
        return tierLeverage > 0 ? tierLeverage : maxLeverage;
    }

    /// @notice Get current BNB price in quote token
    function getBnbPrice(address quoteToken) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = quoteToken;
        uint256[] memory amounts = router.getAmountsOut(1 ether, path);
        return amounts[1];
    }

    /// @notice Calculate health factor for a position
    function getHealthFactor(uint256 positionId) public view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.borrowedAmount == 0) return type(uint256).max;
        
        uint256 positionValue = getPositionValue(positionId);
        uint256 debtValue = pos.borrowedAmount;
        
        if (debtValue == 0) return type(uint256).max;
        return (positionValue * BPS) / debtValue;
    }

    /// @notice Get the current USD value of a position's LP tokens
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

    /// @notice Check if a position can be liquidated
    function canLiquidate(uint256 positionId) public view returns (bool) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.borrowedAmount == 0) return false;
        
        uint256 healthFactor = getHealthFactor(positionId);
        return healthFactor < liquidationThreshold;
    }

    /// @notice Get pending CAKE rewards for a position
    function getPendingCake(uint256 positionId) external view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive) return 0;
        PoolConfig memory pool = poolConfigs[pos.lpToken];
        return masterChef.pendingCake(pool.pid, address(this));
    }

    // ============ User Functions ============

    /// @notice Open a leveraged position
    function openPosition(address lpToken, uint256 leverage) external payable nonReentrant {
        require(msg.value >= 0.01 ether, "Min 0.01 BNB");
        
        uint256 userMaxLev = getUserMaxLeverage(msg.sender);
        require(leverage >= 10000 && leverage <= userMaxLev, "Invalid leverage");
        
        PoolConfig memory pool = poolConfigs[lpToken];
        require(pool.isActive, "Pool not active");

        uint256 bnbAmount = msg.value;
        
        // Calculate and deduct open fee
        uint256 openFee = getEffectiveFee(msg.sender, fees.openFeeBps);
        uint256 feeAmount = (bnbAmount * openFee) / BPS;
        if (feeAmount > 0) {
            (bool sent,) = treasury.call{value: feeAmount}("");
            require(sent, "Fee transfer failed");
            bnbAmount -= feeAmount;
        }
        
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

        // Store entry BNB price
        uint256 entryPrice = getBnbPrice(pool.quoteToken);

        // === Proper ratio calculation (from V4) ===
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
        
        // Target 50% in quote tokens
        uint256 targetQuoteAmount = totalValueInQuote / 2;
        
        uint256 quoteForLiquidity;
        uint256 bnbForLiquidity;
        
        if (borrowAmount < targetQuoteAmount) {
            uint256 quoteNeeded = targetQuoteAmount - borrowAmount;
            
            address[] memory swapPath = new address[](2);
            swapPath[0] = WBNB;
            swapPath[1] = pool.quoteToken;
            
            uint256 bnbToSwap = (bnbAmount * quoteNeeded) / bnbValue[1];
            if (bnbToSwap > bnbAmount * 95 / 100) bnbToSwap = bnbAmount * 95 / 100;
            
            uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbToSwap}(
                0, swapPath, address(this), block.timestamp
            );
            
            quoteForLiquidity = borrowAmount + swapAmounts[1];
            bnbForLiquidity = bnbAmount - bnbToSwap;
        } else {
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
        
        // Add liquidity
        IERC20(pool.quoteToken).forceApprove(address(router), quoteForLiquidity);
        
        (uint256 usedQuote, uint256 usedBNB, uint256 lpReceived) = router.addLiquidityETH{value: bnbForLiquidity}(
            pool.quoteToken, quoteForLiquidity, 0, 0, address(this), block.timestamp
        );
        
        // Handle leftovers - return to user
        uint256 leftoverQuote = quoteForLiquidity - usedQuote;
        uint256 leftoverBNB = bnbForLiquidity - usedBNB;
        
        if (leftoverQuote > 1000) {
            IERC20(pool.quoteToken).forceApprove(address(router), leftoverQuote);
            address[] memory returnPath = new address[](2);
            returnPath[0] = pool.quoteToken;
            returnPath[1] = WBNB;
            try router.swapExactTokensForETH(leftoverQuote, 0, returnPath, msg.sender, block.timestamp) {} catch {}
        }
        
        if (leftoverBNB > 0) {
            (bool sent,) = msg.sender.call{value: leftoverBNB}("");
            // Don't revert on failure
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
            collateralBNB: msg.value, // Original amount before fees
            borrowedAmount: borrowAmount,
            lpAmount: lpReceived,
            leverage: leverage,
            openTimestamp: block.timestamp,
            entryBnbPrice: entryPrice,
            isActive: true
        });
        
        userPositions[msg.sender].push(positionId);

        emit PositionOpened(positionId, msg.sender, msg.value, borrowAmount, lpReceived, leverage, entryPrice);
    }

    /// @notice Close your own position
    function closePosition(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(pos.owner == msg.sender, "Not owner");

        _closePosition(positionId, pos.owner, false, address(0));
    }

    /// @notice Liquidate an underwater position
    function liquidate(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(canLiquidate(positionId), "Position healthy");
        require(msg.sender != pos.owner, "Cannot liquidate own position");

        _closePosition(positionId, pos.owner, true, msg.sender);
    }

    /// @notice Harvest CAKE rewards
    function harvest(uint256 positionId) external nonReentrant {
        Position storage pos = positions[positionId];
        require(pos.isActive, "Position not active");
        require(pos.owner == msg.sender, "Not owner");

        PoolConfig memory pool = poolConfigs[pos.lpToken];
        
        masterChef.withdraw(pool.pid, 0);
        
        uint256 cakeBalance = IERC20(CAKE).balanceOf(address(this));
        if (cakeBalance > 0) {
            uint256 perfFee = getEffectiveFee(msg.sender, fees.performanceFeeBps);
            uint256 feeAmount = (cakeBalance * perfFee) / BPS;
            uint256 userAmount = cakeBalance - feeAmount;
            
            if (feeAmount > 0) {
                IERC20(CAKE).safeTransfer(treasury, feeAmount);
            }
            if (userAmount > 0) {
                IERC20(CAKE).safeTransfer(msg.sender, userAmount);
            }
            
            emit Harvested(positionId, userAmount, feeAmount);
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

        // Withdraw LP from MasterChef
        masterChef.withdraw(pool.pid, pos.lpAmount);

        // Remove liquidity
        IERC20(pos.lpToken).forceApprove(address(router), pos.lpAmount);
        (uint256 quoteReceived, uint256 bnbReceived) = router.removeLiquidityETH(
            pos.quoteToken, pos.lpAmount, 0, 0, address(this), block.timestamp
        );

        uint256 totalFeesCollected = 0;
        uint256 badDebt = 0;
        uint256 liquidatorReward = 0;
        uint256 treasuryLiqFee = 0;

        // === Calculate Price Appreciation Fee ===
        if (!isLiquidation && bnbReceived > 0) {
            uint256 currentPrice = getBnbPrice(pos.quoteToken);
            
            if (currentPrice > pos.entryBnbPrice) {
                // Price increased - calculate fee on gains
                uint256 priceIncreaseBps = ((currentPrice - pos.entryBnbPrice) * BPS) / pos.entryBnbPrice;
                uint256 bnbGainValue = (bnbReceived * priceIncreaseBps) / BPS;
                
                // Convert gain to BNB amount
                uint256 gainInBnb = (bnbReceived * priceIncreaseBps) / (BPS + priceIncreaseBps);
                
                // Apply price appreciation fee (reduced by staking)
                uint256 priceFee = getEffectiveFee(owner, fees.priceApprecFeeBps);
                uint256 appreciationFee = (gainInBnb * priceFee) / BPS;
                
                if (appreciationFee > 0 && appreciationFee < bnbReceived) {
                    (bool sent,) = treasury.call{value: appreciationFee}("");
                    if (sent) {
                        bnbReceived -= appreciationFee;
                        totalFeesCollected += appreciationFee;
                    }
                }
            }
        }

        // === Apply Close Fee ===
        if (!isLiquidation && bnbReceived > 0) {
            uint256 closeFee = getEffectiveFee(owner, fees.closeFeeBps);
            uint256 closeFeeAmount = (bnbReceived * closeFee) / BPS;
            
            if (closeFeeAmount > 0) {
                (bool sent,) = treasury.call{value: closeFeeAmount}("");
                if (sent) {
                    bnbReceived -= closeFeeAmount;
                    totalFeesCollected += closeFeeAmount;
                }
            }
        }

        // === Repay Debt ===
        if (pos.borrowedAmount > 0 && address(lendingPool) != address(0)) {
            uint256 toRepay = pos.borrowedAmount;
            
            if (quoteReceived >= toRepay) {
                IERC20(pos.quoteToken).forceApprove(address(lendingPool), toRepay);
                lendingPool.repay(toRepay);
                quoteReceived -= toRepay;
                
                // Convert remaining quote to BNB
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
                // Not enough quote - use BNB to cover
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

        // === Handle Liquidation ===
        if (isLiquidation && bnbReceived > 0) {
            // Liquidator bonus
            liquidatorReward = (bnbReceived * liquidationBonus) / BPS;
            
            // Treasury liquidation fee
            treasuryLiqFee = (bnbReceived * fees.liquidationFeeBps) / BPS;
            
            bnbReceived -= (liquidatorReward + treasuryLiqFee);
            
            if (liquidatorReward > 0) {
                (bool sent,) = liquidator.call{value: liquidatorReward}("");
                require(sent, "Liquidator reward failed");
            }
            
            if (treasuryLiqFee > 0) {
                (bool sent,) = treasury.call{value: treasuryLiqFee}("");
                // Don't revert if treasury transfer fails
            }
        }

        // Mark position as closed
        pos.isActive = false;

        // Send remaining BNB to owner
        if (bnbReceived > 0) {
            (bool sent,) = owner.call{value: bnbReceived}("");
            require(sent, "Failed to send BNB");
        }

        if (isLiquidation) {
            emit PositionLiquidated(positionId, liquidator, owner, badDebt, liquidatorReward, treasuryLiqFee);
        } else {
            emit PositionClosed(positionId, owner, bnbReceived, totalFeesCollected);
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

    function setLvgStaking(address _lvgStaking) external onlyOwner {
        lvgStaking = ILVGStaking(_lvgStaking);
    }

    function setFees(
        uint256 _openFee,
        uint256 _closeFee,
        uint256 _perfFee,
        uint256 _priceFee,
        uint256 _liqFee
    ) external onlyOwner {
        require(_openFee <= 100, "Open fee too high");     // Max 1%
        require(_closeFee <= 100, "Close fee too high");   // Max 1%
        require(_perfFee <= 3000, "Perf fee too high");    // Max 30%
        require(_priceFee <= 5000, "Price fee too high");  // Max 50%
        require(_liqFee <= 500, "Liq fee too high");       // Max 5%
        
        fees = FeeConfig({
            openFeeBps: _openFee,
            closeFeeBps: _closeFee,
            performanceFeeBps: _perfFee,
            priceApprecFeeBps: _priceFee,
            liquidationFeeBps: _liqFee
        });
        
        emit FeesUpdated(_openFee, _closeFee, _perfFee, _priceFee, _liqFee);
    }

    function setTierMaxLeverage(uint256 tier, uint256 maxLev) external onlyOwner {
        require(tier <= 4, "Invalid tier");
        require(maxLev >= 10000 && maxLev <= 100000, "Invalid leverage");
        tierMaxLeverage[tier] = maxLev;
    }

    function setLiquidationParams(uint256 _threshold, uint256 _bonus) external onlyOwner {
        require(_threshold >= 10000 && _threshold <= 15000, "Invalid threshold");
        require(_bonus <= 1000, "Bonus too high");
        liquidationThreshold = _threshold;
        liquidationBonus = _bonus;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    /// @notice Rescue stuck tokens (emergency function)
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // Rescue BNB
            (bool sent,) = treasury.call{value: amount}("");
            require(sent, "BNB rescue failed");
        } else {
            // Rescue ERC20
            IERC20(token).safeTransfer(treasury, amount);
        }
        emit TokensRescued(token, amount);
    }

    receive() external payable {}
}
