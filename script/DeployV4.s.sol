// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/LeveragedFarmV3.sol";
import "../contracts/core/LendingPoolV4.sol";

contract DeployV4 is Script {
    // BSC Mainnet addresses
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant MASTERCHEF = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address constant TREASURY = 0x70ED203A074a916661eF164Bc64Ba7dBa341C664;
    
    // USDT-BNB LP
    address constant USDT_BNB_LP = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    uint256 constant USDT_BNB_PID = 13;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy LendingPoolV4
        LendingPoolV4 pool = new LendingPoolV4(USDT);
        console.log("LendingPoolV4 deployed to:", address(pool));
        
        // Deploy LeveragedFarmV3
        LeveragedFarmV3 farm = new LeveragedFarmV3(ROUTER, MASTERCHEF, CAKE, TREASURY);
        console.log("LeveragedFarmV3 deployed to:", address(farm));
        
        // Connect them
        pool.setVault(address(farm));
        farm.setLendingPool(address(pool));
        
        // Add USDT-BNB pool
        farm.addPool(USDT_BNB_PID, USDT_BNB_LP, USDT);
        
        console.log("Setup complete!");
        console.log("LendingPool:", address(pool));
        console.log("Farm:", address(farm));
        
        vm.stopBroadcast();
    }
}
