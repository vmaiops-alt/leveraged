// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/**
 * @title IPriceOracle
 * @notice Interface for price oracle
 */
interface IPriceOracle {
    
    /**
     * @notice Get the price of an asset in USD
     * @param asset The asset address
     * @return price Price in USD with 8 decimals
     */
    function getPrice(address asset) external view returns (uint256 price);
    
    /**
     * @notice Get the price with a maximum age
     * @param asset The asset address
     * @param maxAge Maximum age of the price in seconds
     * @return price Price in USD with 8 decimals
     */
    function getPriceWithAge(address asset, uint256 maxAge) external view returns (uint256 price);
    
    /**
     * @notice Check if an asset is supported
     * @param asset The asset address
     * @return supported True if supported
     */
    function isAssetSupported(address asset) external view returns (bool);
}
