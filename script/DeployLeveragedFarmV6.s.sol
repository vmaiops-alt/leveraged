// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/LeveragedFarmV6.sol";

contract DeployLeveragedFarmV6 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // BSC Mainnet addresses
        address router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        address masterChef = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652;
        address cake = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
        address treasury = 0x70ED203A074a916661eF164Bc64Ba7dBa341C664;
        
        // Existing contracts
        address lendingPool = 0xC57fecAa960Cb9CA70f8C558153314ed17b64c02;
        address lvgStaking = 0xE6f9eDA0344e0092a6c6Bb8f6D29112646821cf2;
        
        // Pool configs
        address usdtBnbLp = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
        address usdt = 0x55d398326f99059fF775485246999027B3197955;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy V6
        LeveragedFarmV6 farm = new LeveragedFarmV6(
            router,
            masterChef,
            cake,
            treasury,
            lvgStaking
        );
        
        console.log("LeveragedFarmV6 deployed at:", address(farm));
        
        // Configure
        farm.setLendingPool(lendingPool);
        farm.addPool(13, usdtBnbLp, usdt);
        
        console.log("V6 configured with LendingPool and pools");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Call LendingPoolV4.setVault(", address(farm), ")");
        console.log("2. Update frontend config with new address");
    }
}
