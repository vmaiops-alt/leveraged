// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title ILeveragedVault
 * @notice Interface for the main Leveraged Vault contract
 */
interface ILeveragedVault {
    
    // ============ Structs ============
    
    struct Position {
        address user;
        address asset;
        uint256 depositAmount;      // Original deposit in USDT/stablecoin
        uint256 leverageMultiplier; // 1x - 5x (in basis points, 10000 = 1x)
        uint256 totalExposure;      // depositAmount * leverage
        uint256 borrowedAmount;     // Amount borrowed from lending pool
        uint256 entryPrice;         // Asset price at entry (for value tracking)
        uint256 entryTimestamp;
        bool isActive;
    }
    
    // ============ Events ============
    
    event PositionOpened(
        uint256 indexed positionId,
        address indexed user,
        address asset,
        uint256 depositAmount,
        uint256 leverage,
        uint256 entryPrice
    );
    
    event PositionClosed(
        uint256 indexed positionId,
        address indexed user,
        uint256 exitPrice,
        uint256 valueIncrease,
        uint256 platformFee,
        uint256 userPayout
    );
    
    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed user,
        address indexed liquidator,
        uint256 liquidationPrice
    );
    
    event CollateralAdded(
        uint256 indexed positionId,
        uint256 amount
    );
    
    // ============ Functions ============
    
    /**
     * @notice Open a new leveraged position
     * @param asset The asset to get exposure to (BTC, ETH, etc.)
     * @param amount Amount of stablecoin to deposit
     * @param leverage Leverage multiplier in basis points (10000 = 1x, 50000 = 5x)
     * @return positionId The ID of the new position
     */
    function openPosition(
        address asset,
        uint256 amount,
        uint256 leverage
    ) external returns (uint256 positionId);
    
    /**
     * @notice Close a position and withdraw funds
     * @param positionId The position to close
     */
    function closePosition(uint256 positionId) external;
    
    /**
     * @notice Add collateral to an existing position
     * @param positionId The position to add collateral to
     * @param amount Amount of collateral to add
     */
    function addCollateral(uint256 positionId, uint256 amount) external;
    
    /**
     * @notice Get position details
     * @param positionId The position ID
     * @return position The position struct
     */
    function getPosition(uint256 positionId) external view returns (Position memory);
    
    /**
     * @notice Calculate health factor for a position
     * @param positionId The position ID
     * @return healthFactor Health factor (1e18 = 1.0)
     */
    function getHealthFactor(uint256 positionId) external view returns (uint256);
    
    /**
     * @notice Check if a position can be liquidated
     * @param positionId The position ID
     * @return canLiquidate True if position is liquidatable
     */
    function isLiquidatable(uint256 positionId) external view returns (bool);
    
    /**
     * @notice Get all positions for a user
     * @param user The user address
     * @return positionIds Array of position IDs
     */
    function getUserPositions(address user) external view returns (uint256[] memory);
}
