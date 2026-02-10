// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface ILendingPool {
    function deposit(uint256 amount) external returns (uint256 shares);
    function totalDeposits() external view returns (uint256);
    function stablecoin() external view returns (address);
}

/**
 * @title BootstrapLending
 * @notice Seeds the Lending Pools with initial liquidity so users can borrow
 * @dev Run with: forge script script/BootstrapLending.s.sol --rpc-url bsc --broadcast
 */
contract BootstrapLending is Script {
    // ============ BSC Mainnet Token Addresses ============
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant ETH  = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    // ============ Deployed LendingPool Addresses ============
    address constant POOL_USDT = 0xC57fecAa960Cb9CA70f8C558153314ed17b64c02;
    address constant POOL_BTCB = 0x76CEeC1f498A7D7092922eCA05bdCd6E81E31c4D;
    address constant POOL_ETH  = 0x205ff685b9AA336833C329CE0e731756DB81F527;
    address constant POOL_BNB  = 0x9c72C050C4042fe25E27729B1cc81CDbC7cb3D7B;
    
    // ============ Bootstrap Amounts ============
    // USDT: 100 USDT (18 decimals on BSC)
    uint256 constant USDT_AMOUNT = 100 * 1e18;
    
    // BTCB: 0.001 BTC (~$60 at current prices)
    uint256 constant BTCB_AMOUNT = 1e15; // 0.001 * 1e18
    
    // ETH: 0.03 ETH (~$100 at current prices)
    uint256 constant ETH_AMOUNT = 3e16; // 0.03 * 1e18
    
    // BNB: 0.15 BNB (~$100 at current prices)
    uint256 constant BNB_AMOUNT = 15e16; // 0.15 * 1e18

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== BOOTSTRAP LENDING POOLS ===");
        console.log("Deployer:", deployer);
        console.log("");
        
        // Check balances first
        _checkBalances(deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Bootstrap each pool
        _bootstrapPool("USDT", USDT, POOL_USDT, USDT_AMOUNT, deployer);
        _bootstrapPool("BTCB", BTCB, POOL_BTCB, BTCB_AMOUNT, deployer);
        _bootstrapPool("ETH",  ETH,  POOL_ETH,  ETH_AMOUNT,  deployer);
        _bootstrapPool("BNB",  WBNB, POOL_BNB,  BNB_AMOUNT,  deployer);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== BOOTSTRAP COMPLETE ===");
        _printPoolStats();
    }
    
    function _checkBalances(address deployer) internal view {
        console.log("--- Wallet Balances ---");
        
        uint256 usdtBal = IERC20(USDT).balanceOf(deployer);
        uint256 btcbBal = IERC20(BTCB).balanceOf(deployer);
        uint256 ethBal  = IERC20(ETH).balanceOf(deployer);
        uint256 wbnbBal = IERC20(WBNB).balanceOf(deployer);
        
        console.log("USDT balance:", usdtBal / 1e18);
        console.log("USDT needed: ", USDT_AMOUNT / 1e18);
        console.log("BTCB balance:", btcbBal);
        console.log("BTCB needed: ", BTCB_AMOUNT);
        console.log("ETH balance: ", ethBal);
        console.log("ETH needed:  ", ETH_AMOUNT);
        console.log("WBNB balance:", wbnbBal);
        console.log("WBNB needed: ", BNB_AMOUNT);
        console.log("");
        
        // Warnings
        if (usdtBal < USDT_AMOUNT) console.log("WARNING: Insufficient USDT!");
        if (btcbBal < BTCB_AMOUNT) console.log("WARNING: Insufficient BTCB!");
        if (ethBal < ETH_AMOUNT)   console.log("WARNING: Insufficient ETH!");
        if (wbnbBal < BNB_AMOUNT)  console.log("WARNING: Insufficient WBNB!");
    }
    
    function _bootstrapPool(
        string memory name,
        address token,
        address pool,
        uint256 amount,
        address deployer
    ) internal {
        uint256 balance = IERC20(token).balanceOf(deployer);
        
        if (balance < amount) {
            console.log("SKIP", name, "- insufficient balance");
            return;
        }
        
        // Approve
        IERC20(token).approve(pool, amount);
        console.log(name, "approved");
        
        // Deposit
        uint256 shares = ILendingPool(pool).deposit(amount);
        console.log(name, "deposited! Shares:", shares);
    }
    
    function _printPoolStats() internal view {
        console.log("--- Pool TVL After Bootstrap ---");
        console.log("USDT Pool:", ILendingPool(POOL_USDT).totalDeposits() / 1e18, "USDT");
        console.log("BTCB Pool:", ILendingPool(POOL_BTCB).totalDeposits(), "BTCB (wei)");
        console.log("ETH Pool: ", ILendingPool(POOL_ETH).totalDeposits(), "ETH (wei)");
        console.log("BNB Pool: ", ILendingPool(POOL_BNB).totalDeposits(), "BNB (wei)");
    }
    
    // ============ Individual Pool Functions (for manual use) ============
    
    /// @notice Bootstrap only USDT pool
    function bootstrapUSDT() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        _bootstrapPool("USDT", USDT, POOL_USDT, USDT_AMOUNT, deployer);
        vm.stopBroadcast();
    }
    
    /// @notice Bootstrap only BTCB pool
    function bootstrapBTCB() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        _bootstrapPool("BTCB", BTCB, POOL_BTCB, BTCB_AMOUNT, deployer);
        vm.stopBroadcast();
    }
    
    /// @notice Bootstrap only ETH pool
    function bootstrapETH() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        _bootstrapPool("ETH", ETH, POOL_ETH, ETH_AMOUNT, deployer);
        vm.stopBroadcast();
    }
    
    /// @notice Bootstrap only BNB pool
    function bootstrapBNB() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        _bootstrapPool("BNB", WBNB, POOL_BNB, BNB_AMOUNT, deployer);
        vm.stopBroadcast();
    }
}
