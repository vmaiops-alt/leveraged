// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/core/LendingPool.sol";

contract DeployNewPool is Script {
    function run() external {
        address usdt = 0x4fa98902809D863Bf3Bc4D349e6D2C2d74072b74;
        
        vm.startBroadcast();
        
        LendingPool pool = new LendingPool(usdt);
        console.log("LendingPool deployed at:", address(pool));
        
        vm.stopBroadcast();
    }
}
