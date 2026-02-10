// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
}

interface IYieldTokenizer {
    function createMarket(address underlying, uint256 maturity) external returns (bytes32 marketId);
    function deposit(bytes32 marketId, uint256 amount) external returns (uint256 ptAmount, uint256 ytAmount);
    function getMarket(bytes32 marketId) external view returns (
        address underlying,
        address principalToken,
        address yieldToken,
        uint256 maturity,
        uint256 totalDeposited,
        bool active
    );
    function getMarketCount() external view returns (uint256);
    function marketIds(uint256 index) external view returns (bytes32);
}

/**
 * @title BootstrapYieldMarket
 * @notice Creates the first PT/YT market for aUSDT (6-month maturity)
 * @dev Run with: forge script script/BootstrapYieldMarket.s.sol --rpc-url bsc --broadcast
 * 
 * This script:
 * 1. Creates a 6-month aUSDT yield market
 * 2. Deploys PT (Principal Token) and YT (Yield Token)
 * 3. Optionally seeds initial liquidity
 */
contract BootstrapYieldMarket is Script {
    // ============ Deployed Contract ============
    address constant YIELD_TOKENIZER = 0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605;
    
    // ============ BSC Mainnet Yield-Bearing Assets ============
    // Venus aUSDT (vUSDT)
    address constant VENUS_USDT = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
    
    // Alpaca ibUSDT
    address constant ALPACA_USDT = 0x158Da805682BdC8ee32d52833aD41E74bb951E59;
    
    // For simplicity, we'll use regular USDT as underlying (can be swapped for aToken)
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    
    // ============ Market Parameters ============
    uint256 constant SIX_MONTHS = 180 days;
    
    // Initial seed liquidity (optional)
    uint256 constant SEED_AMOUNT = 100 * 1e18; // 100 USDT

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== BOOTSTRAP YIELD MARKET ===");
        console.log("Deployer:", deployer);
        console.log("YieldTokenizer:", YIELD_TOKENIZER);
        console.log("");
        
        // Calculate maturity (6 months from now)
        uint256 maturity = block.timestamp + SIX_MONTHS;
        console.log("Current timestamp:", block.timestamp);
        console.log("Maturity timestamp:", maturity);
        console.log("Maturity in days:", SIX_MONTHS / 1 days);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Create the market
        bytes32 marketId = _createMarket(USDT, maturity);
        
        // 2. Optionally seed liquidity
        uint256 usdtBalance = IERC20(USDT).balanceOf(deployer);
        if (usdtBalance >= SEED_AMOUNT) {
            _seedLiquidity(marketId, SEED_AMOUNT);
        } else {
            console.log("SKIP seeding - insufficient USDT balance");
            console.log("Balance:", usdtBalance / 1e18);
            console.log("Needed:", SEED_AMOUNT / 1e18);
        }
        
        vm.stopBroadcast();
        
        // 3. Print market info
        _printMarketInfo(marketId);
        
        console.log("");
        console.log("=== BOOTSTRAP COMPLETE ===");
    }
    
    function _createMarket(address underlying, uint256 maturity) internal returns (bytes32 marketId) {
        console.log("--- Creating Market ---");
        console.log("Underlying:", underlying);
        
        IYieldTokenizer tokenizer = IYieldTokenizer(YIELD_TOKENIZER);
        
        marketId = tokenizer.createMarket(underlying, maturity);
        
        console.log("Market ID:");
        console.logBytes32(marketId);
        console.log("Market created successfully!");
        console.log("");
    }
    
    function _seedLiquidity(bytes32 marketId, uint256 amount) internal {
        console.log("--- Seeding Liquidity ---");
        console.log("Amount:", amount / 1e18, "USDT");
        
        // Approve USDT
        IERC20(USDT).approve(YIELD_TOKENIZER, amount);
        console.log("Approved USDT");
        
        // Deposit and receive PT + YT
        IYieldTokenizer tokenizer = IYieldTokenizer(YIELD_TOKENIZER);
        (uint256 ptAmount, uint256 ytAmount) = tokenizer.deposit(marketId, amount);
        
        console.log("Received PT:", ptAmount / 1e18);
        console.log("Received YT:", ytAmount / 1e18);
        console.log("");
    }
    
    function _printMarketInfo(bytes32 marketId) internal view {
        console.log("--- Market Info ---");
        
        IYieldTokenizer tokenizer = IYieldTokenizer(YIELD_TOKENIZER);
        
        (
            address underlying,
            address principalToken,
            address yieldToken,
            uint256 maturity,
            uint256 totalDeposited,
            bool active
        ) = tokenizer.getMarket(marketId);
        
        console.log("Underlying:", underlying);
        console.log("Principal Token (PT):", principalToken);
        console.log("Yield Token (YT):", yieldToken);
        console.log("Maturity:", maturity);
        console.log("Total Deposited:", totalDeposited / 1e18);
        console.log("Active:", active);
        
        uint256 marketCount = tokenizer.getMarketCount();
        console.log("Total Markets:", marketCount);
    }
    
    // ============ Utility Functions ============
    
    /// @notice Create market only (no seeding)
    function createMarketOnly() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 maturity = block.timestamp + SIX_MONTHS;
        
        vm.startBroadcast(deployerPrivateKey);
        _createMarket(USDT, maturity);
        vm.stopBroadcast();
    }
    
    /// @notice Seed existing market with liquidity
    function seedMarket(bytes32 marketId, uint256 amount) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        _seedLiquidity(marketId, amount);
        vm.stopBroadcast();
    }
    
    /// @notice Create market with custom maturity (in days)
    function createCustomMarket(address underlying, uint256 daysUntilMaturity) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 maturity = block.timestamp + (daysUntilMaturity * 1 days);
        
        console.log("Creating market with", daysUntilMaturity, "days until maturity");
        
        vm.startBroadcast(deployerPrivateKey);
        bytes32 marketId = _createMarket(underlying, maturity);
        vm.stopBroadcast();
        
        _printMarketInfo(marketId);
    }
    
    /// @notice View all existing markets
    function viewMarkets() external view {
        IYieldTokenizer tokenizer = IYieldTokenizer(YIELD_TOKENIZER);
        uint256 count = tokenizer.getMarketCount();
        
        console.log("=== ALL MARKETS ===");
        console.log("Total count:", count);
        
        for (uint256 i = 0; i < count; i++) {
            bytes32 marketId = tokenizer.marketIds(i);
            console.log("");
            console.log("Market", i);
            console.logBytes32(marketId);
            _printMarketInfo(marketId);
        }
    }
}
