// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/LeveragedFarmV4.sol";

contract DeployLeveragedFarmV4 is Script {
    // BSC Mainnet addresses
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant MASTERCHEF_V2 = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant USDT_BNB_LP = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    
    // Existing LendingPoolV4
    address constant LENDING_POOL_V4 = 0xC57fecAa960Cb9CA70f8C558153314ed17b64c02;
    
    // Treasury
    address constant TREASURY = 0x70ED203A074a916661eF164Bc64Ba7dBa341C664;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LeveragedFarmV4
        LeveragedFarmV4 farm = new LeveragedFarmV4(
            PANCAKE_ROUTER,
            MASTERCHEF_V2,
            CAKE,
            TREASURY
        );

        console.log("LeveragedFarmV4 deployed at:", address(farm));

        // Configure the farm
        farm.setLendingPool(LENDING_POOL_V4);
        console.log("Lending pool set to:", LENDING_POOL_V4);

        // Add USDT-BNB pool (PID 13)
        farm.addPool(13, USDT_BNB_LP, USDT);
        console.log("Added USDT-BNB pool with PID 13");

        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("LeveragedFarmV4:", address(farm));
        console.log("");
        console.log("Next steps:");
        console.log("1. Update frontend contracts.ts with new farm address");
        console.log("2. Set this farm as borrower on LendingPoolV4");
    }
}
