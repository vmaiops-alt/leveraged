// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/core/LendingPool.sol";

interface ILeveragedFarm {
    function setLendingPool(address _lendingPool) external;
}

contract DeployLendingPoolMainnet is Script {
    // BSC Mainnet addresses
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;  // BSC-USD (USDT)
    address constant LEVERAGED_FARM = 0xCE066289D798300ceFCC1B6FdEa5dD10AF113486;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy LendingPool with USDT
        LendingPool lendingPool = new LendingPool(USDT);
        console.log("LendingPool deployed:", address(lendingPool));
        
        // Set LeveragedFarm as the vault (allowed to borrow)
        lendingPool.setVault(LEVERAGED_FARM);
        console.log("Vault set to LeveragedFarm:", LEVERAGED_FARM);
        
        // Connect LendingPool to LeveragedFarm
        ILeveragedFarm(LEVERAGED_FARM).setLendingPool(address(lendingPool));
        console.log("LendingPool connected to LeveragedFarm");
        
        vm.stopBroadcast();
        
        console.log("\n=== LENDING POOL DEPLOYMENT ===");
        console.log("Network: BSC Mainnet");
        console.log("LendingPool:", address(lendingPool));
        console.log("Stablecoin: USDT", USDT);
        console.log("Vault: LeveragedFarm", LEVERAGED_FARM);
    }
}
