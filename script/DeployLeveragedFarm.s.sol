// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/LeveragedFarm.sol";

contract DeployLeveragedFarm is Script {
    // BSC Mainnet addresses
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant PANCAKE_MASTERCHEF = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652; // MasterChef v2
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    
    // Popular LP tokens
    address constant CAKE_BNB_LP = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
    address constant USDT_BNB_LP = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    address constant BUSD_BNB_LP = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    address constant ETH_BNB_LP = 0x74E4716E431f45807DCF19f284c7aA99F18a4fbc;
    
    // Pool IDs in MasterChef v2
    uint256 constant CAKE_BNB_PID = 2;
    uint256 constant USDT_BNB_PID = 11;
    uint256 constant BUSD_BNB_PID = 3;
    uint256 constant ETH_BNB_PID = 5;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy LeveragedFarm
        LeveragedFarm farm = new LeveragedFarm(
            PANCAKE_ROUTER,
            PANCAKE_MASTERCHEF,
            CAKE,
            treasury
        );
        console.log("LeveragedFarm deployed:", address(farm));
        
        // Add pools
        farm.addPool(CAKE_BNB_PID, CAKE_BNB_LP);
        console.log("Added CAKE-BNB pool (PID:", CAKE_BNB_PID, ")");
        
        farm.addPool(USDT_BNB_PID, USDT_BNB_LP);
        console.log("Added USDT-BNB pool (PID:", USDT_BNB_PID, ")");
        
        farm.addPool(BUSD_BNB_PID, BUSD_BNB_LP);
        console.log("Added BUSD-BNB pool (PID:", BUSD_BNB_PID, ")");
        
        farm.addPool(ETH_BNB_PID, ETH_BNB_LP);
        console.log("Added ETH-BNB pool (PID:", ETH_BNB_PID, ")");
        
        vm.stopBroadcast();
        
        console.log("\n=== LEVERAGED FARM DEPLOYMENT ===");
        console.log("Network: BSC Mainnet");
        console.log("LeveragedFarm:", address(farm));
        console.log("Treasury:", treasury);
        console.log("\nPools:");
        console.log("- CAKE-BNB:", CAKE_BNB_LP);
        console.log("- USDT-BNB:", USDT_BNB_LP);
        console.log("- BUSD-BNB:", BUSD_BNB_LP);
        console.log("- ETH-BNB:", ETH_BNB_LP);
    }
}
