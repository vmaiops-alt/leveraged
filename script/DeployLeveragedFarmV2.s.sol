// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/LeveragedFarmV2.sol";

contract DeployLeveragedFarmV2 is Script {
    // BSC Mainnet
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant PANCAKE_MASTERCHEF = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    
    // LP tokens and quote tokens
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    
    address constant USDT_BNB_LP = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    address constant BUSD_BNB_LP = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    address constant ETH_BNB_LP = 0x74E4716E431f45807DCF19f284c7aA99F18a4fbc;
    address constant CAKE_BNB_LP = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
    
    // PIDs
    uint256 constant USDT_BNB_PID = 11;
    uint256 constant BUSD_BNB_PID = 3;
    uint256 constant ETH_BNB_PID = 5;
    uint256 constant CAKE_BNB_PID = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        LeveragedFarmV2 farm = new LeveragedFarmV2(
            PANCAKE_ROUTER,
            PANCAKE_MASTERCHEF,
            CAKE,
            treasury
        );
        console.log("LeveragedFarmV2 deployed:", address(farm));
        
        // Add pools
        farm.addPool(USDT_BNB_PID, USDT_BNB_LP, USDT);
        console.log("Added USDT-BNB pool");
        
        farm.addPool(BUSD_BNB_PID, BUSD_BNB_LP, BUSD);
        console.log("Added BUSD-BNB pool");
        
        farm.addPool(ETH_BNB_PID, ETH_BNB_LP, ETH);
        console.log("Added ETH-BNB pool");
        
        farm.addPool(CAKE_BNB_PID, CAKE_BNB_LP, CAKE);
        console.log("Added CAKE-BNB pool");
        
        vm.stopBroadcast();
        
        console.log("\n=== LEVERAGED FARM V2 ===");
        console.log("Address:", address(farm));
        console.log("Treasury:", treasury);
    }
}
