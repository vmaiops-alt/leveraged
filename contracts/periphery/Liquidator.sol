// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/ILiquidator.sol";
import "../interfaces/ILeveragedVault.sol";

/**
 * @title Liquidator
 * @notice Liquidation engine for LEVERAGED protocol
 * @dev Manages keepers and provides batch liquidation capabilities
 */
contract Liquidator is ILiquidator {
    
    // ============ Constants ============
    
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant KEEPER_INCENTIVE_BPS = 100; // 1% extra for keepers
    uint256 public constant BPS_DENOMINATOR = 10000;
    
    // ============ State ============
    
    address public owner;
    ILeveragedVault public vault;
    
    mapping(address => bool) public keepers;
    address[] public keeperList;
    
    bool public paused;
    bool public keeperOnlyMode; // If true, only keepers can liquidate
    
    // ============ Events ============
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event KeeperOnlyModeSet(bool enabled);
    event VaultUpdated(address indexed oldVault, address indexed newVault);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }
    
    modifier onlyKeeperOrPublic() {
        if (keeperOnlyMode) {
            require(keepers[msg.sender], "Not authorized keeper");
        }
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _vault) {
        require(_vault != address(0), "Invalid vault");
        owner = msg.sender;
        vault = ILeveragedVault(_vault);
        keeperOnlyMode = false; // Public liquidations by default
    }
    
    // ============ Admin Functions ============
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
    
    function setKeeperOnlyMode(bool enabled) external onlyOwner {
        keeperOnlyMode = enabled;
        emit KeeperOnlyModeSet(enabled);
    }
    
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        emit VaultUpdated(address(vault), _vault);
        vault = ILeveragedVault(_vault);
    }
    
    /**
     * @notice Add a keeper address
     * @param keeper Address to add as keeper
     */
    function addKeeper(address keeper) external onlyOwner {
        require(keeper != address(0), "Invalid keeper");
        require(!keepers[keeper], "Already keeper");
        
        keepers[keeper] = true;
        keeperList.push(keeper);
        
        emit KeeperAdded(keeper);
    }
    
    /**
     * @notice Remove a keeper address
     * @param keeper Address to remove
     */
    function removeKeeper(address keeper) external onlyOwner {
        require(keepers[keeper], "Not keeper");
        
        keepers[keeper] = false;
        
        // Remove from list (swap and pop)
        for (uint256 i = 0; i < keeperList.length; i++) {
            if (keeperList[i] == keeper) {
                keeperList[i] = keeperList[keeperList.length - 1];
                keeperList.pop();
                break;
            }
        }
        
        emit KeeperRemoved(keeper);
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Liquidate an unhealthy position
     * @param positionId The position to liquidate
     * @return debtRepaid Amount of debt repaid
     * @return collateralSeized Amount of collateral seized
     */
    function liquidate(uint256 positionId) 
        external 
        override 
        whenNotPaused 
        onlyKeeperOrPublic 
        returns (uint256 debtRepaid, uint256 collateralSeized) 
    {
        // Check if position is liquidatable
        require(vault.isLiquidatable(positionId), "Position not liquidatable");
        
        // Get position info before liquidation
        ILeveragedVault.Position memory position = vault.getPosition(positionId);
        require(position.isActive, "Position not active");
        
        // Calculate expected values (for event)
        uint256 healthFactor = vault.getHealthFactor(positionId);
        
        // Execute liquidation through vault
        // Note: The vault handles the actual liquidation logic
        vault.liquidate(positionId);
        
        // Estimate debt repaid and collateral seized based on position
        // These are approximations for the event
        debtRepaid = position.borrowedAmount;
        collateralSeized = position.totalExposure;
        
        // Calculate liquidator bonus (from vault's LIQUIDATION_BONUS)
        uint256 liquidatorBonus = (collateralSeized * 500) / BPS_DENOMINATOR; // 5% as per vault
        
        emit LiquidationExecuted(
            positionId,
            msg.sender,
            debtRepaid,
            collateralSeized,
            liquidatorBonus
        );
        
        return (debtRepaid, collateralSeized);
    }
    
    /**
     * @notice Batch liquidate multiple positions
     * @param positionIds Array of position IDs
     * @return totalDebtRepaid Total debt repaid
     * @return totalCollateralSeized Total collateral seized
     */
    function batchLiquidate(uint256[] calldata positionIds) 
        external 
        override 
        whenNotPaused 
        onlyKeeperOrPublic 
        returns (uint256 totalDebtRepaid, uint256 totalCollateralSeized) 
    {
        require(positionIds.length > 0, "Empty array");
        require(positionIds.length <= MAX_BATCH_SIZE, "Exceeds max batch size");
        
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < positionIds.length; i++) {
            uint256 positionId = positionIds[i];
            
            // Skip if not liquidatable (don't revert whole batch)
            if (!vault.isLiquidatable(positionId)) {
                continue;
            }
            
            // Get position info
            ILeveragedVault.Position memory position = vault.getPosition(positionId);
            if (!position.isActive) {
                continue;
            }
            
            // Try to liquidate (catch failures to continue batch)
            try vault.liquidate(positionId) {
                totalDebtRepaid += position.borrowedAmount;
                totalCollateralSeized += position.totalExposure;
                successCount++;
                
                uint256 liquidatorBonus = (position.totalExposure * 500) / BPS_DENOMINATOR;
                
                emit LiquidationExecuted(
                    positionId,
                    msg.sender,
                    position.borrowedAmount,
                    position.totalExposure,
                    liquidatorBonus
                );
            } catch {
                // Skip failed liquidations
                continue;
            }
        }
        
        require(successCount > 0, "No liquidations executed");
        
        return (totalDebtRepaid, totalCollateralSeized);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get liquidatable positions
     * @param maxPositions Maximum positions to return
     * @return positionIds Array of liquidatable position IDs
     */
    function getLiquidatablePositions(uint256 maxPositions) 
        external 
        view 
        override 
        returns (uint256[] memory) 
    {
        require(maxPositions > 0 && maxPositions <= MAX_BATCH_SIZE, "Invalid maxPositions");
        
        // Get total positions from vault (we'll scan from 0 to nextPositionId)
        // Note: This is a simplified scan - production would use subgraph/indexer
        uint256[] memory tempPositions = new uint256[](maxPositions);
        uint256 count = 0;
        
        // Scan positions (starting from 0)
        // This is gas-intensive - in production, use off-chain indexing
        for (uint256 i = 0; count < maxPositions; i++) {
            // Try to get position (will revert if doesn't exist)
            try vault.getPosition(i) returns (ILeveragedVault.Position memory position) {
                if (!position.isActive) {
                    continue;
                }
                
                if (vault.isLiquidatable(i)) {
                    tempPositions[count] = i;
                    count++;
                }
            } catch {
                // No more positions
                break;
            }
        }
        
        // Trim array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tempPositions[i];
        }
        
        return result;
    }
    
    /**
     * @notice Check if caller is authorized keeper
     * @param keeper Address to check
     * @return True if authorized
     */
    function isKeeper(address keeper) external view override returns (bool) {
        return keepers[keeper];
    }
    
    /**
     * @notice Get all keepers
     * @return Array of keeper addresses
     */
    function getAllKeepers() external view returns (address[] memory) {
        return keeperList;
    }
    
    /**
     * @notice Get keeper count
     * @return Number of registered keepers
     */
    function getKeeperCount() external view returns (uint256) {
        return keeperList.length;
    }
    
    /**
     * @notice Check if liquidations are restricted to keepers
     * @return True if keeper-only mode is enabled
     */
    function isKeeperOnlyMode() external view returns (bool) {
        return keeperOnlyMode;
    }
    
    /**
     * @notice Estimate liquidation reward for a position
     * @param positionId Position to estimate
     * @return bonus Expected liquidator bonus
     */
    function estimateLiquidationReward(uint256 positionId) external view returns (uint256 bonus) {
        if (!vault.isLiquidatable(positionId)) {
            return 0;
        }
        
        ILeveragedVault.Position memory position = vault.getPosition(positionId);
        if (!position.isActive) {
            return 0;
        }
        
        // 5% of total exposure as bonus
        bonus = (position.totalExposure * 500) / BPS_DENOMINATOR;
    }
}
