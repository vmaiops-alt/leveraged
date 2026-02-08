// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/IPriceOracle.sol";

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

/**
 * @title PriceOracle
 * @notice Chainlink-based price oracle for asset prices
 * @dev Supports multiple assets with fallback mechanisms
 */
contract PriceOracle is IPriceOracle {
    
    // ============ State ============
    
    address public owner;
    
    mapping(address => address) public priceFeeds;  // asset => chainlink feed
    mapping(address => bool) public supportedAssets;
    
    uint256 public constant MAX_PRICE_AGE = 1 hours;
    uint256 public constant PRICE_DECIMALS = 8;
    
    // ============ Events ============
    
    event PriceFeedSet(address indexed asset, address indexed feed);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // ============ Constructor ============
    
    constructor() {
        owner = msg.sender;
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Set price feed for an asset
     * @param asset The asset address
     * @param feed The Chainlink price feed address
     */
    function setPriceFeed(address asset, address feed) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        require(feed != address(0), "Invalid feed");
        
        priceFeeds[asset] = feed;
        supportedAssets[asset] = true;
        
        emit PriceFeedSet(asset, feed);
    }
    
    /**
     * @notice Remove price feed for an asset
     * @param asset The asset address
     */
    function removePriceFeed(address asset) external onlyOwner {
        delete priceFeeds[asset];
        supportedAssets[asset] = false;
    }
    
    /**
     * @notice Transfer ownership
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get the price of an asset in USD
     * @param asset The asset address
     * @return price Price in USD with 8 decimals
     */
    function getPrice(address asset) external view override returns (uint256 price) {
        return _getPrice(asset, MAX_PRICE_AGE);
    }
    
    /**
     * @notice Get the price with a maximum age
     * @param asset The asset address
     * @param maxAge Maximum age of the price in seconds
     * @return price Price in USD with 8 decimals
     */
    function getPriceWithAge(address asset, uint256 maxAge) external view override returns (uint256 price) {
        return _getPrice(asset, maxAge);
    }
    
    /**
     * @notice Check if an asset is supported
     * @param asset The asset address
     * @return supported True if supported
     */
    function isAssetSupported(address asset) external view override returns (bool) {
        return supportedAssets[asset];
    }
    
    // ============ Internal Functions ============
    
    function _getPrice(address asset, uint256 maxAge) internal view returns (uint256) {
        require(supportedAssets[asset], "Asset not supported");
        
        address feed = priceFeeds[asset];
        require(feed != address(0), "No price feed");
        
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed);
        
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        // Validate price data
        require(answer > 0, "Invalid price");
        require(updatedAt > 0, "Round not complete");
        require(answeredInRound >= roundId, "Stale price");
        require(block.timestamp - updatedAt <= maxAge, "Price too old");
        
        // Normalize to 8 decimals
        uint8 feedDecimals = priceFeed.decimals();
        if (feedDecimals == PRICE_DECIMALS) {
            return uint256(answer);
        } else if (feedDecimals < PRICE_DECIMALS) {
            return uint256(answer) * 10**(PRICE_DECIMALS - feedDecimals);
        } else {
            return uint256(answer) / 10**(feedDecimals - PRICE_DECIMALS);
        }
    }
}
