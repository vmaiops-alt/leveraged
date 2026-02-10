// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/crosschain/LVGTokenOFT.sol";
import "../contracts/config/LayerZeroConfig.sol";

/**
 * @title DeployArbitrum
 * @notice Deploy LVGTokenOFT on Arbitrum One as a secondary chain
 * @dev 
 * Deployment:
 *   forge script script/DeployArbitrum.s.sol:DeployArbitrum --rpc-url arbitrum --broadcast --verify
 * 
 * Verification only:
 *   forge script script/DeployArbitrum.s.sol:DeployArbitrum --sig "verify(address)" <DEPLOYED_ADDRESS> --rpc-url arbitrum
 * 
 * Environment Variables Required:
 *   - PRIVATE_KEY: Deployer private key
 *   - ARBITRUM_RPC_URL: Arbitrum One RPC endpoint
 *   - ARBISCAN_API_KEY: Arbiscan API key for verification
 */
contract DeployArbitrum is Script {
    // LayerZero V2 Endpoint on Arbitrum One (same universal endpoint across all chains)
    address public constant ARBITRUM_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    
    // Arbitrum One Chain ID
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;
    
    // LayerZero Endpoint ID for Arbitrum
    uint32 public constant ARBITRUM_EID = 30110;
    
    // Deployed token address (set after deployment for peer configuration)
    address public deployedToken;
    
    /**
     * @notice Deploy LVGTokenOFT on Arbitrum One
     * @dev Arbitrum is a secondary chain, so no initial mint
     */
    function run() external returns (address tokenAddress) {
        // Verify we're on Arbitrum
        require(block.chainid == ARBITRUM_CHAIN_ID, "Must deploy on Arbitrum One (chainId: 42161)");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Arbitrum LVGTokenOFT Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("LayerZero Endpoint:", ARBITRUM_LZ_ENDPOINT);
        console.log("LayerZero EID:", ARBITRUM_EID);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy LVGTokenOFT with no initial supply (secondary chain)
        LVGTokenOFT token = new LVGTokenOFT(
            ARBITRUM_LZ_ENDPOINT,
            0 // No initial supply on secondary chains - tokens bridged from BSC
        );
        
        tokenAddress = address(token);
        deployedToken = tokenAddress;
        
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("LVGTokenOFT deployed at:", tokenAddress);
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Total supply:", token.totalSupply());
        console.log("Owner:", token.owner());
        console.log("Max supply:", token.MAX_SUPPLY());
        
        vm.stopBroadcast();
        
        // Log next steps
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Deploy on BSC if not already deployed");
        console.log("2. Run ConfigurePeers.s.sol to link BSC <-> Arbitrum");
        console.log("3. Optionally set rate limits");
        console.log("");
        console.log("Verify with:");
        console.log("  forge verify-contract", tokenAddress, "contracts/crosschain/LVGTokenOFT.sol:LVGTokenOFT --chain arbitrum --constructor-args $(cast abi-encode 'constructor(address,uint256)' 0x1a44076050125825900e736c501f859c50fE728c 0)");
        
        return tokenAddress;
    }
    
    /**
     * @notice Verify an already deployed LVGTokenOFT contract on Arbiscan
     * @param tokenAddress Address of the deployed token to verify
     */
    function verify(address tokenAddress) external view {
        require(block.chainid == ARBITRUM_CHAIN_ID, "Must run on Arbitrum One");
        require(tokenAddress != address(0), "Invalid token address");
        
        // Verify the contract exists and has expected properties
        LVGTokenOFT token = LVGTokenOFT(tokenAddress);
        
        console.log("=== Verification Info ===");
        console.log("Contract:", tokenAddress);
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Owner:", token.owner());
        console.log("");
        console.log("Run verification command:");
        console.log("forge verify-contract \\");
        console.log("  ", tokenAddress, "\\");
        console.log("  contracts/crosschain/LVGTokenOFT.sol:LVGTokenOFT \\");
        console.log("  --chain arbitrum \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(address,uint256)' 0x1a44076050125825900e736c501f859c50fE728c 0)");
    }
    
    /**
     * @notice Check deployment readiness
     */
    function preflight() external view {
        console.log("=== Preflight Check ===");
        console.log("Chain ID:", block.chainid);
        
        if (block.chainid != ARBITRUM_CHAIN_ID) {
            console.log("[FAIL] Not on Arbitrum One. Expected chainId:", ARBITRUM_CHAIN_ID);
            return;
        }
        console.log("[OK] Chain ID matches Arbitrum One");
        
        // Check LZ endpoint exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(0x1a44076050125825900e736c501f859c50fE728c)
        }
        
        if (codeSize == 0) {
            console.log("[FAIL] LayerZero endpoint not found");
            return;
        }
        console.log("[OK] LayerZero endpoint exists");
        
        console.log("");
        console.log("All preflight checks passed. Ready to deploy!");
    }
}
