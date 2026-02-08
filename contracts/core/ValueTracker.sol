// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/IValueTracker.sol";
import "../interfaces/IPriceOracle.sol";

/**
 * @title ValueTracker
 * @notice Tracks entry/exit values for calculating the 25% value increase fee
 * @dev This is the core of the platform's revenue model
 */
contract ValueTracker is IValueTracker {
    
    // ============ Constants ============
    
    uint256 public constant VALUE_INCREASE_FEE_BPS = 2500; // 25%
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant PRICE_DECIMALS = 8;
    
    // ============ State ============
    
    address public owner;
    address public vault;           // Only vault can record/calculate
    IPriceOracle public priceOracle;
    
    mapping(uint256 => ValueRecord) public valueRecords; // positionId => record
    
    // ============ Events ============
    
    event VaultSet(address indexed vault);
    event OracleSet(address indexed oracle);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVault() {
        require(msg.sender == vault, "Not vault");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _priceOracle) {
        owner = msg.sender;
        priceOracle = IPriceOracle(_priceOracle);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Set the vault address
     * @param _vault The vault contract address
     */
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        vault = _vault;
        emit VaultSet(_vault);
    }
    
    /**
     * @notice Set the price oracle
     * @param _oracle The oracle address
     */
    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        priceOracle = IPriceOracle(_oracle);
        emit OracleSet(_oracle);
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Record entry value for a position
     * @param positionId The position ID
     * @param asset The asset address
     * @param depositValue The deposit value in USD (with 18 decimals)
     */
    function recordEntry(
        uint256 positionId,
        address asset,
        uint256 depositValue
    ) external override onlyVault {
        require(valueRecords[positionId].entryTimestamp == 0, "Already recorded");
        
        uint256 entryPrice = priceOracle.getPrice(asset);
        
        valueRecords[positionId] = ValueRecord({
            entryPrice: entryPrice,
            entryTimestamp: block.timestamp,
            depositValue: depositValue
        });
        
        emit ValueRecorded(positionId, asset, entryPrice, depositValue);
    }
    
    /**
     * @notice Calculate value increase and platform fee
     * @param positionId The position ID
     * @param currentPrice Current asset price (8 decimals)
     * @return valueIncrease Total value increase
     * @return platformFee 25% fee for platform
     * @return userAmount Amount user receives from value increase
     */
    function calculateValueIncrease(
        uint256 positionId,
        uint256 currentPrice
    ) external view override returns (
        uint256 valueIncrease,
        uint256 platformFee,
        uint256 userAmount
    ) {
        ValueRecord memory record = valueRecords[positionId];
        require(record.entryTimestamp > 0, "No record");
        
        // If price went down or stayed same, no value increase fee
        if (currentPrice <= record.entryPrice) {
            return (0, 0, 0);
        }
        
        // Calculate value increase
        // valueIncrease = depositValue * (currentPrice - entryPrice) / entryPrice
        uint256 priceIncrease = currentPrice - record.entryPrice;
        valueIncrease = (record.depositValue * priceIncrease) / record.entryPrice;
        
        // Calculate 25% platform fee
        platformFee = (valueIncrease * VALUE_INCREASE_FEE_BPS) / BPS_DENOMINATOR;
        
        // User gets 75% of value increase
        userAmount = valueIncrease - platformFee;
        
        emit ValueIncreaseCalculated(
            positionId,
            record.depositValue,
            record.depositValue + valueIncrease,
            valueIncrease,
            platformFee
        );
    }
    
    /**
     * @notice Get value record for a position
     * @param positionId The position ID
     * @return record The value record
     */
    function getValueRecord(uint256 positionId) external view override returns (ValueRecord memory) {
        return valueRecords[positionId];
    }
    
    /**
     * @notice Calculate projected value increase (for UI)
     * @param entryPrice Entry price
     * @param currentPrice Current price
     * @param depositValue Deposit value
     * @return valueIncrease Projected value increase
     * @return platformFee Projected platform fee
     */
    function calculateProjectedValueIncrease(
        uint256 entryPrice,
        uint256 currentPrice,
        uint256 depositValue
    ) external pure returns (uint256 valueIncrease, uint256 platformFee) {
        if (currentPrice <= entryPrice) {
            return (0, 0);
        }
        
        uint256 priceIncrease = currentPrice - entryPrice;
        valueIncrease = (depositValue * priceIncrease) / entryPrice;
        platformFee = (valueIncrease * VALUE_INCREASE_FEE_BPS) / BPS_DENOMINATOR;
    }
}
