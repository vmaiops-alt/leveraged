// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title LeveragedFarmV3 - With Liquidation Mechanism
/// @notice Leveraged yield farming with health factor monitoring and liquidation

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

contract LeveragedFarmV3 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Position {
        address owner;
        address lpToken;
        address quoteToken;
        uint256 collateralBNB;
        uint256 borrowedAmount;
        uint256 lpAmount;
        uint256 leverage;        // 10000 = 1x, 20000 = 2x, 30000 = 3x
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
    
    // Risk parameters
    uint256 public constant PRECISION = 10000;
    uint256 public maxLeverage = 30000;              // 3x max
    uint256 public liquidationThreshold = 11000;     // 110% - liquidate when health < 1.1
    uint256 public liquidationBonus = 500;           // 5% bonus for liquidators
    uint256 public performanceFee = 1000;            // 10%
    
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
        insuranceFund = _treasury; // Default to treasury, can be changed
        
        IERC20(_cake).forceApprove(_router, type(uint256).max);
    }

    // ============ View Functions ============

    /// @notice Calculate health factor for a position
    /// @return healthFactor in basis points (10000 = 1.0, 15000 = 1.5)
    function getHealthFactor(uint256 positionId) public view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.borrowedAmount == 0) return type(uint256).max;
        
        uint256 positionValue = getPositionValue(positionId);
        uint256 debtValue = pos.borrowedAmount; // Already in USD terms (stablecoin)
        
        if (debtValue == 0) return type(uint256).max;
        return (positionValue * PRECISION) / debtValue;
    }

    /// @notice Get the current USD value of a position's LP tokens
    function getPositionValue(uint256 positionId) public view returns (uint256) {
        Position memory pos = positions[positionId];
        if (!pos.isActive || pos.lpAmount == 0) return 0;
        
        IPancakePair pair = IPancakePair(pos.lpToken);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 totalSupply = pair.totalSupply();
        
        if (totalSupply == 0) return 0;
        
        // Calculate LP token's share of reserves
        uint256 share0 = (uint256(reserve0) * pos.lpAmount) / totalSupply;
        uint256 share1 = (uint256(reserve1) * pos.lpAmount) / totalSupply;
        
        // Convert to USD value (assuming quoteToken is stablecoin)
        address token0 = pair.token0();
        if (token0 == pos.quoteToken) {
            // token0 is stablecoin, token1 is BNB
            // Value = stablecoin amount + BNB converted to stablecoin
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pos.quoteToken;
            uint256[] memory amounts = router.getAmountsOut(share1, path);
            return share0 + amounts[1];
        } else {
            // token1 is stablecoin, token0 is BNB
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

    // ============ User Functions ============

    /// @notice Open a leveraged position
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
            
            // Get quote token amount for the extra leverage
            address[] memory path = new address[](2);
            path[0] = WBNB;
            path[1] = pool.quoteToken;
            uint256[] memory amounts = router.getAmountsOut((bnbAmount * leverageExtra) / 10000, path);
            borrowAmount = amounts[1];
            
            // Borrow from lending pool
            lendingPool.borrow(borrowAmount);
        }

        // Swap half of BNB to quote token
        uint256 bnbForSwap = bnbAmount / 2;
        uint256 bnbForLiquidity = bnbAmount - bnbForSwap;
        
        address[] memory swapPath = new address[](2);
        swapPath[0] = WBNB;
        swapPath[1] = pool.quoteToken;
        
        uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbForSwap}(
            0, swapPath, address(this), block.timestamp
        );
        uint256 quoteFromSwap = swapAmounts[1];
        
        uint256 totalQuoteTokens = quoteFromSwap + borrowAmount;
        
        // Add liquidity
        IERC20(pool.quoteToken).forceApprove(address(router), totalQuoteTokens);
        
        (,, uint256 lpReceived) = router.addLiquidityETH{value: bnbForLiquidity}(
            pool.quoteToken, totalQuoteTokens, 0, 0, address(this), block.timestamp
        );

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

        uint256 badDebt = 0;
        uint256 liquidatorReward = 0;
        uint256 returnToBorrower = 0;

        // Repay debt if any
        if (pos.borrowedAmount > 0 && address(lendingPool) != address(0)) {
            uint256 toRepay = pos.borrowedAmount;
            
            if (quoteReceived >= toRepay) {
                // Enough to repay fully
                IERC20(pos.quoteToken).forceApprove(address(lendingPool), toRepay);
                lendingPool.repay(toRepay);
                quoteReceived -= toRepay;
                
                // Convert remaining quote to BNB for user
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
                // Not enough - partial repay + bad debt
                if (quoteReceived > 0) {
                    IERC20(pos.quoteToken).forceApprove(address(lendingPool), quoteReceived);
                    lendingPool.repay(quoteReceived);
                }
                badDebt = toRepay - quoteReceived;
                
                // Try to cover from BNB
                if (bnbReceived > 0 && badDebt > 0) {
                    address[] memory path = new address[](2);
                    path[0] = WBNB;
                    path[1] = pos.quoteToken;
                    uint256[] memory neededAmounts = router.getAmountsOut(bnbReceived, path);
                    
                    if (neededAmounts[1] >= badDebt) {
                        // Can cover bad debt with BNB
                        uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbReceived}(
                            0, path, address(this), block.timestamp
                        );
                        IERC20(pos.quoteToken).forceApprove(address(lendingPool), badDebt);
                        lendingPool.repay(badDebt);
                        
                        // Return excess
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
                        // Swap all BNB but still have bad debt
                        uint256[] memory swapAmounts = router.swapExactETHForTokens{value: bnbReceived}(
                            0, path, address(this), block.timestamp
                        );
                        IERC20(pos.quoteToken).forceApprove(address(lendingPool), swapAmounts[1]);
                        lendingPool.repay(swapAmounts[1]);
                        badDebt -= swapAmounts[1];
                        bnbReceived = 0;
                    }
                }
                
                // If still bad debt, cover from insurance
                if (badDebt > 0) {
                    lendingPool.coverBadDebt(badDebt);
                }
                
                quoteReceived = 0;
            }
        }

        // Handle liquidation bonus
        if (isLiquidation && bnbReceived > 0) {
            liquidatorReward = (bnbReceived * liquidationBonus) / PRECISION;
            bnbReceived -= liquidatorReward;
            
            // Send bonus to liquidator
            (bool sent,) = liquidator.call{value: liquidatorReward}("");
            require(sent, "Failed to send liquidator reward");
        }

        // Mark position as closed
        pos.isActive = false;
        returnToBorrower = bnbReceived;

        // Send remaining BNB to owner
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
