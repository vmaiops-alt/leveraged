// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/crosschain/LVGTokenOFT.sol";
import "../contracts/config/LayerZeroConfig.sol";

/**
 * @title DeployLVGTokenOFT
 * @notice Deploy LVG Token OFT across multiple chains
 * @dev Run with: forge script script/DeployLVGTokenOFT.s.sol:DeployLVGTokenOFT --rpc-url <rpc> --broadcast
 * 
 * Environment Variables Required:
 * - PRIVATE_KEY: Deployer private key
 * - BSC_RPC_URL / ARBITRUM_RPC_URL / BASE_RPC_URL: RPC endpoints
 */
contract DeployLVGTokenOFT is Script {
    
    // Initial supply - only minted on BSC (origin chain)
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18; // 100M tokens
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy LVGTokenOFT
        LVGTokenOFT token = new LVGTokenOFT(
            LayerZeroConfig.LZ_ENDPOINT_V2,
            INITIAL_SUPPLY // Mint initial supply on origin chain
        );
        
        console.log("LVGTokenOFT deployed at:", address(token));
        console.log("Initial supply:", token.totalSupply());
        console.log("Owner:", token.owner());
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Deploy on secondary chain (no initial mint)
     */
    function deploySecondary() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = new LVGTokenOFT(
            LayerZeroConfig.LZ_ENDPOINT_V2,
            0 // No initial supply on secondary chains
        );
        
        console.log("LVGTokenOFT (secondary) deployed at:", address(token));
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Configure peers after deployment on all chains
     * @param tokenAddress Address of the deployed token
     * @param bscPeer BSC peer address
     * @param arbitrumPeer Arbitrum peer address
     * @param basePeer Base peer address
     */
    function configurePeers(
        address tokenAddress,
        address bscPeer,
        address arbitrumPeer,
        address basePeer
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = LVGTokenOFT(tokenAddress);
        
        // Set BSC peer
        if (bscPeer != address(0)) {
            token.setPeer(
                LayerZeroConfig.EID_BSC,
                bytes32(uint256(uint160(bscPeer)))
            );
            console.log("BSC peer set:", bscPeer);
        }
        
        // Set Arbitrum peer
        if (arbitrumPeer != address(0)) {
            token.setPeer(
                LayerZeroConfig.EID_ARBITRUM,
                bytes32(uint256(uint160(arbitrumPeer)))
            );
            console.log("Arbitrum peer set:", arbitrumPeer);
        }
        
        // Set Base peer
        if (basePeer != address(0)) {
            token.setPeer(
                LayerZeroConfig.EID_BASE,
                bytes32(uint256(uint160(basePeer)))
            );
            console.log("Base peer set:", basePeer);
        }
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Set rate limits for cross-chain transfers
     * @param tokenAddress Address of the deployed token
     * @param dailyLimit Daily transfer limit per chain
     */
    function setRateLimits(
        address tokenAddress,
        uint256 dailyLimit
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = LVGTokenOFT(tokenAddress);
        uint256 window = 24 hours;
        
        // Set limits for all supported chains
        token.setRateLimit(LayerZeroConfig.EID_BSC, dailyLimit, window);
        token.setRateLimit(LayerZeroConfig.EID_ARBITRUM, dailyLimit, window);
        token.setRateLimit(LayerZeroConfig.EID_BASE, dailyLimit, window);
        
        console.log("Rate limits set to", dailyLimit, "per 24 hours");
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Grant minter role to an address
     * @param tokenAddress Address of the deployed token
     * @param minter Address to grant minter role
     */
    function addMinter(address tokenAddress, address minter) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = LVGTokenOFT(tokenAddress);
        token.setMinter(minter, true);
        
        console.log("Minter added:", minter);
        
        vm.stopBroadcast();
    }
}
