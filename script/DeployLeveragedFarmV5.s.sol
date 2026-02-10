// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/LeveragedFarmV5.sol";

contract DeployLeveragedFarmV5 is Script {
    // BSC Mainnet addresses
    address constant PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant MASTERCHEF_V2 = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652;
    address constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant USDT_BNB_LP = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    
    // Existing contracts
    address constant LENDING_POOL_V4 = 0xC57fecAa960Cb9CA70f8C558153314ed17b64c02;
    address constant LVG_STAKING = 0xE6f9eDA0344e0092a6c6Bb8f6D29112646821cf2;
    
    // Treasury (deployer wallet for now)
    address constant TREASURY = 0x70ED203A074a916661eF164Bc64Ba7dBa341C664;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy LeveragedFarmV5
        LeveragedFarmV5 farm = new LeveragedFarmV5(
            PANCAKE_ROUTER,
            MASTERCHEF_V2,
            CAKE,
            TREASURY,
            LVG_STAKING
        );

        console.log("LeveragedFarmV5 deployed at:", address(farm));

        // Configure the farm
        farm.setLendingPool(LENDING_POOL_V4);
        console.log("Lending pool set to:", LENDING_POOL_V4);

        // Add USDT-BNB pool (PID 13)
        farm.addPool(13, USDT_BNB_LP, USDT);
        console.log("Added USDT-BNB pool with PID 13");

        vm.stopBroadcast();
        
        console.log("");
        console.log("=== V5 Deployment Complete ===");
        console.log("LeveragedFarmV5:", address(farm));
        console.log("");
        console.log("Features:");
        console.log("- Open Fee: 0.1%");
        console.log("- Close Fee: 0.1%");
        console.log("- Performance Fee: 10%");
        console.log("- Price Appreciation Fee: 25%");
        console.log("- Liquidation Treasury Fee: 1%");
        console.log("- LVG Staking integration for fee reduction");
        console.log("- Tier-based max leverage (up to 5x for Diamond)");
        console.log("- rescueTokens() for emergencies");
        console.log("");
        console.log("Next steps:");
        console.log("1. Update frontend contracts.ts");
        console.log("2. Set V5 as vault on LendingPoolV4");
    }
}
