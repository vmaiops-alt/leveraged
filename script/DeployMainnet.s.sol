// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/vaults/VenusVault.sol";
import "../contracts/vaults/VenusBNBVault.sol";

contract DeployMainnet is Script {
    // BSC Mainnet addresses
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;  // BSC-USD (USDT)
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;  // BUSD
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;  // USDC
    
    // Venus vTokens
    address constant vUSDT = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
    address constant vBUSD = 0x95c78222B3D6e262426483D42CfA53685A67Ab9D;
    address constant vUSDC = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
    
    // Treasury (receives fees)
    address treasury;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        treasury = vm.addr(deployerPrivateKey);  // Use deployer as treasury initially
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Venus USDT Vault
        VenusVault usdtVault = new VenusVault(
            USDT,
            vUSDT,
            treasury
        );
        console.log("Venus USDT Vault deployed:", address(usdtVault));
        
        // Deploy Venus BUSD Vault
        VenusVault busdVault = new VenusVault(
            BUSD,
            vBUSD,
            treasury
        );
        console.log("Venus BUSD Vault deployed:", address(busdVault));
        
        // Deploy Venus USDC Vault
        VenusVault usdcVault = new VenusVault(
            USDC,
            vUSDC,
            treasury
        );
        console.log("Venus USDC Vault deployed:", address(usdcVault));
        
        // Deploy Venus BNB Vault
        VenusBNBVault bnbVault = new VenusBNBVault(treasury);
        console.log("Venus BNB Vault deployed:", address(bnbVault));
        
        vm.stopBroadcast();
        
        // Summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: BSC Mainnet");
        console.log("Treasury:", treasury);
        console.log("");
        console.log("USDT Vault:", address(usdtVault));
        console.log("BUSD Vault:", address(busdVault));
        console.log("USDC Vault:", address(usdcVault));
        console.log("BNB Vault:", address(bnbVault));
    }
}
