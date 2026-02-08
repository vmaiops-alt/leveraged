// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title Deploy
 * @notice Deployment script for Leveraged platform
 */
contract Deploy {
    
    // ============ Addresses (BSC Mainnet) ============
    
    // Stablecoins
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    
    // Chainlink Price Feeds (BSC)
    address constant BTC_USD_FEED = 0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf;
    address constant ETH_USD_FEED = 0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e;
    address constant BNB_USD_FEED = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
    
    // Wrapped tokens (for price feed mapping)
    address constant WBTC = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant WETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    // ============ Addresses (BSC Testnet) ============
    
    address constant TESTNET_USDT = 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd;
    address constant TESTNET_BTC_FEED = 0x5741306c21795FdCBb9b265Ea0255F499DFe515C;
    address constant TESTNET_ETH_FEED = 0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7;
    address constant TESTNET_BNB_FEED = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;
    
    // ============ Deployment Order ============
    
    /*
    1. Deploy PriceOracle
    2. Configure price feeds
    3. Deploy LVGToken
    4. Deploy LendingPool
    5. Deploy ValueTracker
    6. Deploy LeveragedVault
    7. Deploy FeeCollector
    8. Deploy Liquidator
    9. Deploy LVGStaking
    10. Configure all cross-references
    11. Initial token distribution
    */
    
    // ============ Deployment Functions ============
    
    function deployTestnet() external {
        // Step 1: Price Oracle
        // PriceOracle oracle = new PriceOracle();
        // oracle.setPriceFeed(WBTC, TESTNET_BTC_FEED);
        // oracle.setPriceFeed(WETH, TESTNET_ETH_FEED);
        // oracle.setPriceFeed(WBNB, TESTNET_BNB_FEED);
        
        // Step 2: LVG Token
        // LVGToken lvg = new LVGToken();
        
        // Step 3: Lending Pool
        // LendingPool pool = new LendingPool(TESTNET_USDT);
        
        // Step 4: Value Tracker
        // ValueTracker tracker = new ValueTracker(address(oracle));
        
        // Step 5: Leveraged Vault
        // LeveragedVault vault = new LeveragedVault(
        //     TESTNET_USDT,
        //     address(pool),
        //     address(oracle),
        //     address(tracker)
        // );
        
        // Step 6: Fee Collector
        // FeeCollector fees = new FeeCollector(msg.sender);
        
        // Step 7: Liquidator
        // Liquidator liquidator = new Liquidator(address(vault), TESTNET_USDT);
        
        // Step 8: LVG Staking
        // LVGStaking staking = new LVGStaking(address(lvg), TESTNET_USDT);
        
        // Step 9: Configure
        // pool.setVault(address(vault));
        // tracker.setVault(address(vault));
        // fees.setVault(address(vault));
        // fees.setStakingContract(address(staking));
        // vault.setFeeCollector(address(fees));
        // vault.setSupportedAsset(WBTC, true);
        // vault.setSupportedAsset(WETH, true);
        // vault.setSupportedAsset(WBNB, true);
        // lvg.setMinter(address(staking));
        
        // Step 10: Initial Distribution
        // lvg.initialDistribution(
        //     TEAM_WALLET,
        //     TREASURY_WALLET,
        //     LIQUIDITY_WALLET,
        //     PRIVATE_SALE_WALLET,
        //     AIRDROP_WALLET
        // );
    }
    
    function deployMainnet() external {
        // Same as testnet but with mainnet addresses
        // IMPORTANT: Use multisig for owner addresses
        // IMPORTANT: Get audit before mainnet deployment
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

*/
