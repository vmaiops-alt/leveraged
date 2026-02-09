// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/LendingPoolV2.sol";

contract DeployLendingPoolV2 is Script {
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant FARM_V2 = 0x5B59aa75ef67426F691E34802903a3A0DA77bbAa;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        LendingPoolV2 pool = new LendingPoolV2(USDT);
        pool.setVault(FARM_V2);
        
        console.log("LendingPoolV2 deployed to:", address(pool));
        
        vm.stopBroadcast();
    }
}
