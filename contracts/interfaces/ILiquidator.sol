// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title ILiquidator
 * @notice Interface for the liquidation engine
 */
interface ILiquidator {
    
    // ============ Events ============
    
    event LiquidationExecuted(
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized,
        uint256 liquidatorBonus
    );
    
    event KeeperAdded(address indexed keeper);
    event KeeperRemoved(address indexed keeper);
    
    // ============ Functions ============
    
    /**
     * @notice Liquidate an unhealthy position
     * @param positionId The position to liquidate
     * @return debtRepaid Amount of debt repaid
     * @return collateralSeized Amount of collateral seized
     */
    function liquidate(uint256 positionId) external returns (
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    
    /**
     * @notice Batch liquidate multiple positions
     * @param positionIds Array of position IDs
     * @return totalDebtRepaid Total debt repaid
     * @return totalCollateralSeized Total collateral seized
     */
    function batchLiquidate(uint256[] calldata positionIds) external returns (
        uint256 totalDebtRepaid,
        uint256 totalCollateralSeized
    );
    
    /**
     * @notice Get liquidatable positions
     * @param maxPositions Maximum positions to return
     * @return positionIds Array of liquidatable position IDs
     */
    function getLiquidatablePositions(uint256 maxPositions) external view returns (uint256[] memory);
    
    /**
     * @notice Check if caller is authorized keeper
     * @param keeper Address to check
     * @return isKeeper True if authorized
     */
    function isKeeper(address keeper) external view returns (bool);
}
