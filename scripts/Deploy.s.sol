// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/periphery/PriceOracle.sol";
import "../contracts/core/LendingPool.sol";
import "../contracts/core/ValueTracker.sol";
import "../contracts/core/LeveragedVault.sol";
import "../contracts/core/FeeCollector.sol";
import "../contracts/periphery/Liquidator.sol";
import "../contracts/token/LVGToken.sol";
import "../contracts/token/LVGStaking.sol";

/**
 * @title Deploy
 * @notice Deployment script for LEVERAGED platform
 * @dev Run with: forge script scripts/Deploy.s.sol:DeployTestnet --rpc-url $BSC_TESTNET_RPC --broadcast
 */
contract DeployTestnet is Script {
    
    // ============ BSC Testnet Addresses ============
    
    address constant USDT = 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd;
    
    // Chainlink Price Feeds (BSC Testnet)
    address constant BTC_USD_FEED = 0x5741306c21795FdCBb9b265Ea0255F499DFe515C;
    address constant ETH_USD_FEED = 0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7;
    address constant BNB_USD_FEED = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;
    
    // Mock wrapped tokens for price mapping
    address constant WBTC = 0x0000000000000000000000000000000000000001;
    address constant WETH = 0x0000000000000000000000000000000000000002;
    address constant WBNB = 0x0000000000000000000000000000000000000003;
    
    // ============ Deployed Contracts ============
    
    PriceOracle public oracle;
    LendingPool public lendingPool;
    ValueTracker public valueTracker;
    LeveragedVault public vault;
    FeeCollector public feeCollector;
    Liquidator public liquidator;
    LVGToken public lvgToken;
    LVGStaking public lvgStaking;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying from:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy Price Oracle
        oracle = new PriceOracle();
        console.log("PriceOracle:", address(oracle));
        
        // Configure price feeds
        oracle.setPriceFeed(WBTC, BTC_USD_FEED);
        oracle.setPriceFeed(WETH, ETH_USD_FEED);
        oracle.setPriceFeed(WBNB, BNB_USD_FEED);
        
        // 2. Deploy LVG Token
        lvgToken = new LVGToken();
        console.log("LVGToken:", address(lvgToken));
        
        // 3. Deploy Lending Pool
        lendingPool = new LendingPool(USDT);
        console.log("LendingPool:", address(lendingPool));
        
        // 4. Deploy Value Tracker
        valueTracker = new ValueTracker(address(oracle));
        console.log("ValueTracker:", address(valueTracker));
        
        // 5. Deploy Leveraged Vault
        vault = new LeveragedVault(
            USDT,
            address(lendingPool),
            address(oracle),
            address(valueTracker)
        );
        console.log("LeveragedVault:", address(vault));
        
        // 6. Deploy Fee Collector
        feeCollector = new FeeCollector(
            deployer,           // treasury
            deployer,           // insurance fund (same for now)
            address(0)          // staking (set later)
        );
        console.log("FeeCollector:", address(feeCollector));
        
        // 7. Deploy Liquidator
        liquidator = new Liquidator(address(vault));
        console.log("Liquidator:", address(liquidator));
        
        // 8. Deploy LVG Staking
        lvgStaking = new LVGStaking(address(lvgToken), USDT);
        console.log("LVGStaking:", address(lvgStaking));
        
        // ============ Configure Cross-References ============
        
        // Lending Pool
        lendingPool.setVault(address(vault));
        
        // Value Tracker
        valueTracker.setVault(address(vault));
        
        // Fee Collector
        feeCollector.setVault(address(vault));
        feeCollector.setStakingContract(address(lvgStaking));
        feeCollector.addSupportedToken(USDT);
        
        // Vault
        vault.setFeeCollector(address(feeCollector));
        vault.setSupportedAsset(WBTC, true);
        vault.setSupportedAsset(WETH, true);
        vault.setSupportedAsset(WBNB, true);
        
        // Liquidator - add deployer as keeper
        liquidator.addKeeper(deployer);
        
        vm.stopBroadcast();
        
        // ============ Output Summary ============
        
        console.log("\n========== DEPLOYMENT COMPLETE ==========\n");
        console.log("PriceOracle:     ", address(oracle));
        console.log("LendingPool:     ", address(lendingPool));
        console.log("ValueTracker:    ", address(valueTracker));
        console.log("LeveragedVault:  ", address(vault));
        console.log("FeeCollector:    ", address(feeCollector));
        console.log("Liquidator:      ", address(liquidator));
        console.log("LVGToken:        ", address(lvgToken));
        console.log("LVGStaking:      ", address(lvgStaking));
        console.log("\n==========================================\n");
    }
}

/**
 * @title DeployMainnet
 * @notice Mainnet deployment script
 * @dev Run with: forge script scripts/Deploy.s.sol:DeployMainnet --rpc-url $BSC_MAINNET_RPC --broadcast --verify
 */
contract DeployMainnet is Script {
    
    // ============ BSC Mainnet Addresses ============
    
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    
    // Chainlink Price Feeds (BSC Mainnet)
    address constant BTC_USD_FEED = 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf;
    address constant ETH_USD_FEED = 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e;
    address constant BNB_USD_FEED = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
    
    // Wrapped tokens
    address constant WBTC = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant WETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    // Multisig addresses (CHANGE BEFORE MAINNET)
    address constant TREASURY = address(0); // TODO: Set multisig
    address constant INSURANCE_FUND = address(0); // TODO: Set multisig
    
    function run() external {
        require(TREASURY != address(0), "Set treasury multisig");
        require(INSURANCE_FUND != address(0), "Set insurance fund multisig");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("!!! MAINNET DEPLOYMENT !!!");
        console.log("Deploying from:", deployer);
        console.log("Treasury:", TREASURY);
        console.log("Insurance Fund:", INSURANCE_FUND);
        
        // Mainnet deployment follows same pattern as testnet
        // with proper multisig addresses
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ... same deployment logic with mainnet addresses ...
        
        vm.stopBroadcast();
    }
}

/*
============ Post-Deployment Checklist ============

[ ] Verify all contracts on BscScan
[ ] Test deposit/withdraw flow
[ ] Test leverage positions (1x, 2x, 5x)
[ ] Test liquidation flow
[ ] Test fee collection and distribution
[ ] Test LVG staking and rewards
[ ] Setup monitoring and alerts
[ ] Add initial liquidity to LVG/USDT pool
[ ] Configure keeper bots for liquidations
[ ] Setup subgraph for indexing

============ Security Checklist ============

[ ] All admin functions use onlyOwner
[ ] Pause functionality works
[ ] Emergency withdraw works
[ ] No reentrancy vulnerabilities
[ ] Integer overflow protection (Solidity 0.8+)
[ ] Price oracle staleness checks
[ ] Liquidation thresholds are safe
[ ] Multisig configured for admin

============ Frontend Config ============

Update frontend/src/config/wagmi.ts with deployed addresses:

CONTRACTS = {
  97: {  // BSC Testnet
    vault: '0x...',
    lendingPool: '0x...',
    feeCollector: '0x...',
    liquidator: '0x...',
    lvgToken: '0x...',
    lvgStaking: '0x...',
    usdt: '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd',
  },
}

*/
