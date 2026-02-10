// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../interfaces/IStrategy.sol";

/**
 * @title StrategyManager
 * @notice Manages multiple yield strategies for the vault
 * @dev Handles allocation, rebalancing, and strategy selection
 */
contract StrategyManager {
    
    // ============ Structs ============
    
    struct StrategyInfo {
        address strategy;
        string name;
        bool active;
        uint256 allocationBPS;  // Target allocation in basis points
        uint256 depositedAmount;
        uint256 lastHarvest;
    }
    
    // ============ State ============
    
    address public owner;
    address public vault;
    
    StrategyInfo[] public strategies;
    mapping(address => uint256) public strategyIndex; // strategy => index + 1 (0 = not found)
    
    uint256 public totalAllocated;
    uint256 public constant BPS = 10000;
    
    // ============ Events ============
    
    event StrategyAdded(address indexed strategy, string name, uint256 allocationBPS);
    event StrategyRemoved(address indexed strategy);
    event StrategyAllocationUpdated(address indexed strategy, uint256 newAllocationBPS);
    event Deposited(address indexed strategy, uint256 amount);
    event Withdrawn(address indexed strategy, uint256 amount);
    event Harvested(address indexed strategy, uint256 amount);
    event Rebalanced(uint256 strategiesRebalanced);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVault() {
        require(msg.sender == vault || msg.sender == owner, "Not vault");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() {
        owner = msg.sender;
    }
    
    // ============ Admin Functions ============
    
    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }
    
    /**
     * @notice Add a new strategy
     * @param strategy Strategy address
     * @param name Strategy name
     * @param allocationBPS Target allocation in BPS
     */
    function addStrategy(
        address strategy,
        string calldata name,
        uint256 allocationBPS
    ) external onlyOwner {
        require(strategy != address(0), "Invalid strategy");
        require(strategyIndex[strategy] == 0, "Strategy exists");
        require(totalAllocated + allocationBPS <= BPS, "Allocation exceeds 100%");
        
        strategies.push(StrategyInfo({
            strategy: strategy,
            name: name,
            active: true,
            allocationBPS: allocationBPS,
            depositedAmount: 0,
            lastHarvest: block.timestamp
        }));
        
        strategyIndex[strategy] = strategies.length; // 1-indexed
        totalAllocated += allocationBPS;
        
        emit StrategyAdded(strategy, name, allocationBPS);
    }
    
    /**
     * @notice Remove a strategy (must withdraw first)
     * @param strategy Strategy address
     */
    function removeStrategy(address strategy) external onlyOwner {
        uint256 idx = strategyIndex[strategy];
        require(idx > 0, "Strategy not found");
        
        StrategyInfo storage info = strategies[idx - 1];
        require(info.depositedAmount == 0, "Withdraw first");
        
        totalAllocated -= info.allocationBPS;
        info.active = false;
        info.allocationBPS = 0;
        
        // Note: We don't remove from array to preserve indices
        delete strategyIndex[strategy];
        
        emit StrategyRemoved(strategy);
    }
    
    /**
     * @notice Update strategy allocation
     * @param strategy Strategy address
     * @param newAllocationBPS New allocation in BPS
     */
    function updateAllocation(address strategy, uint256 newAllocationBPS) external onlyOwner {
        uint256 idx = strategyIndex[strategy];
        require(idx > 0, "Strategy not found");
        
        StrategyInfo storage info = strategies[idx - 1];
        uint256 oldAllocation = info.allocationBPS;
        
        require(totalAllocated - oldAllocation + newAllocationBPS <= BPS, "Exceeds 100%");
        
        totalAllocated = totalAllocated - oldAllocation + newAllocationBPS;
        info.allocationBPS = newAllocationBPS;
        
        emit StrategyAllocationUpdated(strategy, newAllocationBPS);
    }
    
    // ============ Vault Functions ============
    
    /**
     * @notice Deposit funds across strategies based on allocation
     * @param token Token to deposit
     * @param amount Total amount to deposit
     */
    function depositToStrategies(address token, uint256 amount) external onlyVault {
        require(amount > 0, "Zero amount");
        
        // Transfer tokens from vault
        _transferIn(token, msg.sender, amount);
        
        // Deposit to each active strategy based on allocation
        for (uint256 i = 0; i < strategies.length; i++) {
            StrategyInfo storage info = strategies[i];
            if (!info.active || info.allocationBPS == 0) continue;
            
            uint256 strategyAmount = (amount * info.allocationBPS) / totalAllocated;
            if (strategyAmount == 0) continue;
            
            // Approve and deposit
            _approve(token, info.strategy, strategyAmount);
            IStrategy(info.strategy).deposit(strategyAmount);
            
            info.depositedAmount += strategyAmount;
            emit Deposited(info.strategy, strategyAmount);
        }
    }
    
    /**
     * @notice Withdraw funds from strategies
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     * @return withdrawn Actual amount withdrawn
     */
    function withdrawFromStrategies(address token, uint256 amount) external onlyVault returns (uint256 withdrawn) {
        require(amount > 0, "Zero amount");
        
        uint256 remaining = amount;
        
        // Withdraw proportionally from each strategy
        for (uint256 i = 0; i < strategies.length && remaining > 0; i++) {
            StrategyInfo storage info = strategies[i];
            if (!info.active || info.depositedAmount == 0) continue;
            
            uint256 strategyAmount = (amount * info.depositedAmount) / getTotalDeposited();
            if (strategyAmount > info.depositedAmount) {
                strategyAmount = info.depositedAmount;
            }
            if (strategyAmount > remaining) {
                strategyAmount = remaining;
            }
            
            if (strategyAmount > 0) {
                // Calculate shares to withdraw
                uint256 strategyTVL = IStrategy(info.strategy).getTVL();
                uint256 shares = (strategyAmount * IStrategy(info.strategy).getTVL()) / strategyTVL;
                
                uint256 received = IStrategy(info.strategy).withdraw(shares);
                info.depositedAmount -= received;
                withdrawn += received;
                remaining -= received;
                
                emit Withdrawn(info.strategy, received);
            }
        }
        
        // Transfer to vault
        _transferOut(token, msg.sender, withdrawn);
    }
    
    /**
     * @notice Harvest all strategies
     * @return totalHarvested Total value harvested
     */
    function harvestAll() external returns (uint256 totalHarvested) {
        for (uint256 i = 0; i < strategies.length; i++) {
            StrategyInfo storage info = strategies[i];
            if (!info.active) continue;
            
            try IStrategy(info.strategy).harvest() returns (uint256 harvested) {
                totalHarvested += harvested;
                info.depositedAmount += harvested;
                info.lastHarvest = block.timestamp;
                emit Harvested(info.strategy, harvested);
            } catch {
                // Continue if harvest fails
            }
        }
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get total deposited across all strategies
     * @return total Total deposited
     */
    function getTotalDeposited() public view returns (uint256 total) {
        for (uint256 i = 0; i < strategies.length; i++) {
            total += strategies[i].depositedAmount;
        }
    }
    
    /**
     * @notice Get total TVL across all strategies
     * @return tvl Total value locked
     */
    function getTotalTVL() public view returns (uint256 tvl) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                tvl += IStrategy(strategies[i].strategy).getTVL();
            }
        }
    }
    
    /**
     * @notice Get weighted average APY
     * @return apy Average APY in BPS
     */
    function getAverageAPY() external view returns (uint256 apy) {
        uint256 totalTVL = getTotalTVL();
        if (totalTVL == 0) return 0;
        
        uint256 weightedAPY;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].active) {
                uint256 strategyTVL = IStrategy(strategies[i].strategy).getTVL();
                uint256 strategyAPY = IStrategy(strategies[i].strategy).getAPY();
                weightedAPY += (strategyAPY * strategyTVL) / totalTVL;
            }
        }
        apy = weightedAPY;
    }
    
    /**
     * @notice Get number of strategies
     * @return count Number of strategies
     */
    function getStrategyCount() external view returns (uint256) {
        return strategies.length;
    }
    
    /**
     * @notice Get strategy info by index
     * @param index Strategy index
     * @return info Strategy info
     */
    function getStrategy(uint256 index) external view returns (StrategyInfo memory) {
        return strategies[index];
    }
    
    // ============ Internal Functions ============
    
    function _transferIn(address token, address from, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer in failed");
    }
    
    function _transferOut(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer out failed");
    }
    
    function _approve(address token, address spender, uint256 amount) internal {
        (bool success, ) = token.call(
            abi.encodeWithSignature("approve(address,uint256)", spender, amount)
        );
        require(success, "Approve failed");
    }
}
