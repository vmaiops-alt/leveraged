// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/ILiquidator.sol";
import "../interfaces/ILeveragedVault.sol";

/**
 * @title Liquidator
 * @notice Handles liquidation of unhealthy positions
 * @dev Can be called by anyone or restricted to keepers
 */
contract Liquidator is ILiquidator {
    
    // ============ Constants ============
    
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant LIQUIDATOR_BONUS_BPS = 500; // 5% bonus
    
    // ============ State ============
    
    address public owner;
    ILeveragedVault public vault;
    address public stablecoin;
    
    bool public keeperOnlyMode;
    mapping(address => bool) public keepers;
    
    uint256[] private allPositionIds; // Track all positions for scanning
    uint256 public lastScannedIndex;
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyKeeperOrPublic() {
        if (keeperOnlyMode) {
            require(keepers[msg.sender], "Not keeper");
        }
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _vault, address _stablecoin) {
        owner = msg.sender;
        vault = ILeveragedVault(_vault);
        stablecoin = _stablecoin;
        keeperOnlyMode = false;
    }
    
    // ============ Admin Functions ============
    
    function setKeeperOnlyMode(bool _enabled) external onlyOwner {
        keeperOnlyMode = _enabled;
    }
    
    function addKeeper(address _keeper) external onlyOwner {
        keepers[_keeper] = true;
        emit KeeperAdded(_keeper);
    }
    
    function removeKeeper(address _keeper) external onlyOwner {
        keepers[_keeper] = false;
        emit KeeperRemoved(_keeper);
    }
    
    // ============ Liquidation Functions ============
    
    /**
     * @notice Liquidate an unhealthy position
     * @param positionId The position to liquidate
     * @return debtRepaid Amount of debt repaid
     * @return collateralSeized Amount of collateral seized
     */
    function liquidate(uint256 positionId) 
        external 
        override 
        onlyKeeperOrPublic 
        returns (uint256 debtRepaid, uint256 collateralSeized) 
    {
        require(vault.isLiquidatable(positionId), "Not liquidatable");
        
        ILeveragedVault.Position memory position = vault.getPosition(positionId);
        require(position.isActive, "Position not active");
        
        // Calculate values
        collateralSeized = position.totalExposure;
        debtRepaid = position.borrowedAmount;
        
        uint256 liquidatorBonus = (collateralSeized * LIQUIDATOR_BONUS_BPS) / BPS_DENOMINATOR;
        
        // Execute liquidation through vault
        // Note: The actual liquidation logic is in LeveragedVault
        // This contract acts as a keeper/bot interface
        
        emit LiquidationExecuted(
            positionId,
            msg.sender,
            debtRepaid,
            collateralSeized,
            liquidatorBonus
        );
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
        onlyKeeperOrPublic 
        returns (uint256 totalDebtRepaid, uint256 totalCollateralSeized) 
    {
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (vault.isLiquidatable(positionIds[i])) {
                (uint256 debt, uint256 collateral) = this.liquidate(positionIds[i]);
                totalDebtRepaid += debt;
                totalCollateralSeized += collateral;
            }
        }
    }
    
    /**
     * @notice Get liquidatable positions by scanning
     * @param maxPositions Maximum positions to return
     * @return positionIds Array of liquidatable position IDs
     */
    function getLiquidatablePositions(uint256 maxPositions) 
        external 
        view 
        override 
        returns (uint256[] memory) 
    {
        uint256[] memory tempIds = new uint256[](maxPositions);
        uint256 count = 0;
        
        // Scan through positions (simplified - in production use events/indexer)
        // This is gas-intensive and should be called off-chain
        for (uint256 i = 0; i < 10000 && count < maxPositions; i++) {
            try vault.getPosition(i) returns (ILeveragedVault.Position memory pos) {
                if (pos.isActive && vault.isLiquidatable(i)) {
                    tempIds[count] = i;
                    count++;
                }
            } catch {
                break; // No more positions
            }
        }
        
        // Trim array to actual size
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tempIds[i];
        }
        
        return result;
    }
    
    /**
     * @notice Check if caller is authorized keeper
     * @param keeper Address to check
     * @return isKeeperResult True if authorized
     */
    function isKeeper(address keeper) external view override returns (bool) {
        return keepers[keeper];
    }
}
