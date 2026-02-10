// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

// Core
import "../contracts/token/LVGToken.sol";
import "../contracts/token/LVGStaking.sol";
import "../contracts/core/LendingPoolV5.sol";
import "../contracts/LeveragedFarmV3.sol";

// Yield Tokenization
import "../contracts/yield/YieldTokenizer.sol";

// Perpetuals
import "../contracts/perps/PerpVault.sol";
import "../contracts/perps/PositionManager.sol";

// Governance
import "../contracts/governance/VotingEscrow.sol";
import "../contracts/governance/GaugeController.sol";

contract DeployLeveraged2 is Script {
    // BSC Mainnet addresses
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
    address constant ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    
    // PancakeSwap
    address constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant MASTERCHEF = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652;
    
    // Chainlink Price Feeds BSC
    address constant BNB_USD_FEED = 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== LEVERAGED 2.0 DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ============ CORE CONTRACTS ============
        
        // 1. LVG Token (1B supply)
        LVGToken lvg = new LVGToken();
        console.log("1. LVGToken:", address(lvg));
        
        // 2. LVG Staking (LVG as both stake and reward token)
        LVGStaking staking = new LVGStaking(address(lvg), address(lvg));
        console.log("2. LVGStaking:", address(staking));
        
        // 3. LendingPool V5 (USDT pool)
        LendingPoolV5 lendingPool = new LendingPoolV5(USDT);
        console.log("3. LendingPoolV5:", address(lendingPool));
        
        // 4. LeveragedFarm V3
        address treasury = deployer; // Deployer is treasury for now
        LeveragedFarmV3 farm = new LeveragedFarmV3(
            ROUTER,
            MASTERCHEF,
            CAKE,
            treasury
        );
        console.log("4. LeveragedFarmV3:", address(farm));
        
        // ============ YIELD TOKENIZATION ============
        
        // 5. YieldTokenizer
        YieldTokenizer tokenizer = new YieldTokenizer(deployer); // deployer as fee recipient
        console.log("5. YieldTokenizer:", address(tokenizer));
        
        // ============ PERPETUALS ============
        
        // 6. PerpVault (uses BNB price oracle)
        PerpVault perpVault = new PerpVault("LEVERAGED Perp Vault", "LVG-PV", BNB_USD_FEED);
        console.log("6. PerpVault:", address(perpVault));
        
        // 7. PositionManager
        PositionManager positionManager = new PositionManager(
            address(perpVault),
            BNB_USD_FEED
        );
        console.log("7. PositionManager:", address(positionManager));
        
        // ============ GOVERNANCE ============
        
        // 8. VotingEscrow (veLVG)
        VotingEscrow ve = new VotingEscrow(address(lvg));
        console.log("8. VotingEscrow:", address(ve));
        
        // 9. GaugeController
        GaugeController gaugeController = new GaugeController(address(ve));
        console.log("9. GaugeController:", address(gaugeController));
        
        vm.stopBroadcast();
        
        // ============ SUMMARY ============
        console.log("");
        console.log("========== DEPLOYMENT SUMMARY ==========");
        console.log("LVGToken:        ", address(lvg));
        console.log("LVGStaking:      ", address(staking));
        console.log("LendingPoolV5:   ", address(lendingPool));
        console.log("LeveragedFarmV3: ", address(farm));
        console.log("YieldTokenizer:  ", address(tokenizer));
        console.log("PerpVault:       ", address(perpVault));
        console.log("PositionManager: ", address(positionManager));
        console.log("VotingEscrow:    ", address(ve));
        console.log("GaugeController: ", address(gaugeController));
        console.log("=========================================");
    }
}
