// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/crosschain/LVGTokenOFT.sol";
import "../contracts/config/LayerZeroConfig.sol";

/**
 * @title ConfigurePeers
 * @notice Configure trusted peers between LVGTokenOFT deployments on different chains
 * @dev Peers must be set bidirectionally for cross-chain transfers to work
 * 
 * Usage:
 *   # On BSC - set Arbitrum as peer
 *   forge script script/ConfigurePeers.s.sol:ConfigurePeers --sig "setBscToArbitrumPeer(address,address)" <BSC_TOKEN> <ARB_TOKEN> --rpc-url bsc --broadcast
 *   
 *   # On Arbitrum - set BSC as peer
 *   forge script script/ConfigurePeers.s.sol:ConfigurePeers --sig "setArbitrumToBscPeer(address,address)" <ARB_TOKEN> <BSC_TOKEN> --rpc-url arbitrum --broadcast
 *
 * Environment Variables:
 *   - PRIVATE_KEY: Owner private key
 *   - BSC_RPC_URL: BSC RPC endpoint
 *   - ARBITRUM_RPC_URL: Arbitrum RPC endpoint
 */
contract ConfigurePeers is Script {
    
    // Chain IDs
    uint256 public constant BSC_CHAIN_ID = 56;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;
    
    // LayerZero Endpoint IDs
    uint32 public constant BSC_EID = 30102;
    uint32 public constant ARBITRUM_EID = 30110;
    uint32 public constant BASE_EID = 30184;
    
    /**
     * @notice Set Arbitrum as trusted peer on BSC
     * @param bscToken LVGTokenOFT address on BSC
     * @param arbitrumToken LVGTokenOFT address on Arbitrum
     */
    function setBscToArbitrumPeer(address bscToken, address arbitrumToken) external {
        require(block.chainid == BSC_CHAIN_ID, "Must run on BSC");
        require(bscToken != address(0), "Invalid BSC token address");
        require(arbitrumToken != address(0), "Invalid Arbitrum token address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== Setting Arbitrum Peer on BSC ===");
        console.log("BSC Token:", bscToken);
        console.log("Arbitrum Token:", arbitrumToken);
        console.log("Arbitrum EID:", ARBITRUM_EID);
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = LVGTokenOFT(bscToken);
        
        // Convert address to bytes32 for LayerZero peer format
        bytes32 peerBytes = bytes32(uint256(uint160(arbitrumToken)));
        
        token.setPeer(ARBITRUM_EID, peerBytes);
        
        // Verify
        require(token.peers(ARBITRUM_EID) == peerBytes, "Peer not set correctly");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("[SUCCESS] Arbitrum peer set on BSC");
        console.log("Peer bytes32:", vm.toString(peerBytes));
    }
    
    /**
     * @notice Set BSC as trusted peer on Arbitrum
     * @param arbitrumToken LVGTokenOFT address on Arbitrum
     * @param bscToken LVGTokenOFT address on BSC
     */
    function setArbitrumToBscPeer(address arbitrumToken, address bscToken) external {
        require(block.chainid == ARBITRUM_CHAIN_ID, "Must run on Arbitrum");
        require(arbitrumToken != address(0), "Invalid Arbitrum token address");
        require(bscToken != address(0), "Invalid BSC token address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== Setting BSC Peer on Arbitrum ===");
        console.log("Arbitrum Token:", arbitrumToken);
        console.log("BSC Token:", bscToken);
        console.log("BSC EID:", BSC_EID);
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = LVGTokenOFT(arbitrumToken);
        
        // Convert address to bytes32 for LayerZero peer format
        bytes32 peerBytes = bytes32(uint256(uint160(bscToken)));
        
        token.setPeer(BSC_EID, peerBytes);
        
        // Verify
        require(token.peers(BSC_EID) == peerBytes, "Peer not set correctly");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("[SUCCESS] BSC peer set on Arbitrum");
        console.log("Peer bytes32:", vm.toString(peerBytes));
    }
    
    /**
     * @notice Configure all peers for a token on any supported chain
     * @dev Auto-detects current chain and sets all other chains as peers
     * @param localToken Token address on current chain
     * @param bscToken Token address on BSC (or address(0) if not deployed)
     * @param arbitrumToken Token address on Arbitrum (or address(0) if not deployed)
     * @param baseToken Token address on Base (or address(0) if not deployed)
     */
    function configureAllPeers(
        address localToken,
        address bscToken,
        address arbitrumToken,
        address baseToken
    ) external {
        require(localToken != address(0), "Invalid local token address");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== Configuring All Peers ===");
        console.log("Current chain ID:", block.chainid);
        console.log("Local token:", localToken);
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = LVGTokenOFT(localToken);
        
        // Set BSC peer (if not on BSC and BSC address provided)
        if (block.chainid != BSC_CHAIN_ID && bscToken != address(0)) {
            bytes32 bscPeer = bytes32(uint256(uint160(bscToken)));
            token.setPeer(BSC_EID, bscPeer);
            console.log("BSC peer set:", bscToken);
        }
        
        // Set Arbitrum peer (if not on Arbitrum and Arbitrum address provided)
        if (block.chainid != ARBITRUM_CHAIN_ID && arbitrumToken != address(0)) {
            bytes32 arbPeer = bytes32(uint256(uint160(arbitrumToken)));
            token.setPeer(ARBITRUM_EID, arbPeer);
            console.log("Arbitrum peer set:", arbitrumToken);
        }
        
        // Set Base peer (if not on Base and Base address provided)
        if (block.chainid != 8453 && baseToken != address(0)) {
            bytes32 basePeer = bytes32(uint256(uint160(baseToken)));
            token.setPeer(BASE_EID, basePeer);
            console.log("Base peer set:", baseToken);
        }
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("[SUCCESS] Peer configuration complete");
    }
    
    /**
     * @notice Verify peer configuration between two chains
     * @param tokenAddress Token address on current chain
     * @param expectedPeer Expected peer address
     * @param peerEid LayerZero EID of the peer chain
     */
    function verifyPeer(address tokenAddress, address expectedPeer, uint32 peerEid) external view {
        LVGTokenOFT token = LVGTokenOFT(tokenAddress);
        
        bytes32 expectedPeerBytes = bytes32(uint256(uint160(expectedPeer)));
        bytes32 actualPeer = token.peers(peerEid);
        
        console.log("=== Peer Verification ===");
        console.log("Token:", tokenAddress);
        console.log("Peer EID:", peerEid);
        console.log("Expected peer:", expectedPeer);
        console.log("Expected bytes32:", vm.toString(expectedPeerBytes));
        console.log("Actual bytes32:", vm.toString(actualPeer));
        
        if (actualPeer == expectedPeerBytes) {
            console.log("[OK] Peer configured correctly");
        } else if (actualPeer == bytes32(0)) {
            console.log("[FAIL] No peer configured for this EID");
        } else {
            console.log("[FAIL] Peer mismatch!");
        }
    }
    
    /**
     * @notice Get peer status for all supported chains
     * @param tokenAddress Token address to check
     */
    function getPeerStatus(address tokenAddress) external view {
        LVGTokenOFT token = LVGTokenOFT(tokenAddress);
        
        console.log("=== Peer Status for", tokenAddress, "===");
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        // BSC
        bytes32 bscPeer = token.peers(BSC_EID);
        if (bscPeer != bytes32(0)) {
            console.log("BSC (EID 30102):", address(uint160(uint256(bscPeer))));
        } else {
            console.log("BSC (EID 30102): Not configured");
        }
        
        // Arbitrum
        bytes32 arbPeer = token.peers(ARBITRUM_EID);
        if (arbPeer != bytes32(0)) {
            console.log("Arbitrum (EID 30110):", address(uint160(uint256(arbPeer))));
        } else {
            console.log("Arbitrum (EID 30110): Not configured");
        }
        
        // Base
        bytes32 basePeer = token.peers(BASE_EID);
        if (basePeer != bytes32(0)) {
            console.log("Base (EID 30184):", address(uint160(uint256(basePeer))));
        } else {
            console.log("Base (EID 30184): Not configured");
        }
    }
    
    /**
     * @notice Remove a peer (set to zero)
     * @param tokenAddress Token address on current chain
     * @param peerEid LayerZero EID of the peer to remove
     */
    function removePeer(address tokenAddress, uint32 peerEid) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== Removing Peer ===");
        console.log("Token:", tokenAddress);
        console.log("Peer EID to remove:", peerEid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        LVGTokenOFT token = LVGTokenOFT(tokenAddress);
        token.setPeer(peerEid, bytes32(0));
        
        vm.stopBroadcast();
        
        console.log("[SUCCESS] Peer removed");
    }
    
    /**
     * @notice Batch configure peers using convenient address format
     * @dev Uses setPeerAddress function on LVGTokenOFT
     */
    function setBscArbitrumPeersBidirectional(
        address bscToken,
        address arbitrumToken
    ) external {
        // This function must be called twice - once on each chain
        // It will detect which chain it's on and configure accordingly
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        if (block.chainid == BSC_CHAIN_ID) {
            console.log("=== On BSC: Setting Arbitrum as peer ===");
            LVGTokenOFT(bscToken).setPeerAddress(ARBITRUM_EID, arbitrumToken);
            console.log("[SUCCESS] Arbitrum peer set on BSC");
        } else if (block.chainid == ARBITRUM_CHAIN_ID) {
            console.log("=== On Arbitrum: Setting BSC as peer ===");
            LVGTokenOFT(arbitrumToken).setPeerAddress(BSC_EID, bscToken);
            console.log("[SUCCESS] BSC peer set on Arbitrum");
        } else {
            revert("Must run on BSC or Arbitrum");
        }
        
        vm.stopBroadcast();
    }
}
