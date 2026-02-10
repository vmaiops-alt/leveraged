// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/crosschain/LVGTokenOFT.sol";
import "../contracts/config/LayerZeroConfig.sol";
import "../script/DeployArbitrum.s.sol";
import "../script/ConfigurePeers.s.sol";

/**
 * @title Mock LayerZero Endpoint for deployment testing
 */
contract MockLzEndpointV2 {
    address public delegate;
    
    function setDelegate(address _delegate) external {
        delegate = _delegate;
    }
    
    function quote(
        MessagingParams calldata,
        address
    ) external pure returns (MessagingFee memory) {
        return MessagingFee({ nativeFee: 0.001 ether, lzTokenFee: 0 });
    }
    
    function send(
        MessagingParams calldata,
        address
    ) external payable returns (MessagingReceipt memory) {
        return MessagingReceipt({
            guid: keccak256(abi.encodePacked(block.timestamp)),
            nonce: 1,
            fee: MessagingFee({ nativeFee: msg.value, lzTokenFee: 0 })
        });
    }
}

/**
 * @title ArbitrumDeploymentTest
 * @notice Tests for Arbitrum deployment scripts and peer configuration
 */
contract ArbitrumDeploymentTest is Test {
    // Simulated deployed tokens
    LVGTokenOFT public bscToken;
    LVGTokenOFT public arbitrumToken;
    MockLzEndpointV2 public mockEndpoint;
    
    // Actors
    address public deployer;
    address public user1 = address(0x1001);
    
    function _initActors() internal {
        deployer = makeAddr("deployer");
    }
    
    // Chain IDs
    uint256 constant BSC_CHAIN_ID = 56;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;
    
    // LayerZero EIDs
    uint32 constant BSC_EID = 30102;
    uint32 constant ARBITRUM_EID = 30110;
    uint32 constant BASE_EID = 30184;
    
    // Initial supply on BSC (origin chain)
    uint256 constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    
    function setUp() public {
        _initActors();
        
        // Deploy mock endpoint
        mockEndpoint = new MockLzEndpointV2();
        
        // Deploy tokens as they would be on each chain
        // BSC: Origin chain with initial supply
        vm.prank(deployer);
        bscToken = new LVGTokenOFT(address(mockEndpoint), INITIAL_SUPPLY);
        
        // Arbitrum: Secondary chain, no initial supply
        vm.prank(deployer);
        arbitrumToken = new LVGTokenOFT(address(mockEndpoint), 0);
    }
    
    // ============ DeployArbitrum Tests ============
    
    function test_ArbitrumDeployment_NoInitialSupply() public view {
        // Secondary chain should have zero supply
        assertEq(arbitrumToken.totalSupply(), 0);
        assertEq(arbitrumToken.balanceOf(deployer), 0);
    }
    
    function test_ArbitrumDeployment_CorrectOwner() public view {
        assertEq(arbitrumToken.owner(), deployer);
    }
    
    function test_ArbitrumDeployment_TokenMetadata() public view {
        assertEq(arbitrumToken.name(), "Leveraged");
        assertEq(arbitrumToken.symbol(), "LVG");
        assertEq(arbitrumToken.decimals(), 18);
    }
    
    function test_ArbitrumDeployment_MaxSupply() public view {
        assertEq(arbitrumToken.MAX_SUPPLY(), 1_000_000_000 * 1e18);
    }
    
    function test_ArbitrumDeployment_EndpointSet() public view {
        assertEq(address(arbitrumToken.endpoint()), address(mockEndpoint));
    }
    
    function test_ArbitrumDeployment_NoPeersInitially() public view {
        assertFalse(arbitrumToken.hasPeer(BSC_EID));
        assertFalse(arbitrumToken.hasPeer(BASE_EID));
    }
    
    // ============ BSC Deployment Comparison Tests ============
    
    function test_BSCDeployment_HasInitialSupply() public view {
        // BSC is origin chain with initial supply
        assertEq(bscToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(bscToken.balanceOf(deployer), INITIAL_SUPPLY);
    }
    
    function test_BothDeploymentsUseSameEndpoint() public view {
        // In production, same endpoint address on different chains
        assertEq(address(bscToken.endpoint()), address(arbitrumToken.endpoint()));
    }
    
    // ============ ConfigurePeers Tests ============
    
    function test_SetBscPeerOnArbitrum() public {
        vm.prank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, address(bscToken));
        
        assertTrue(arbitrumToken.hasPeer(BSC_EID));
        assertEq(arbitrumToken.getPeerAddress(BSC_EID), address(bscToken));
    }
    
    function test_SetArbitrumPeerOnBsc() public {
        vm.prank(deployer);
        bscToken.setPeerAddress(ARBITRUM_EID, address(arbitrumToken));
        
        assertTrue(bscToken.hasPeer(ARBITRUM_EID));
        assertEq(bscToken.getPeerAddress(ARBITRUM_EID), address(arbitrumToken));
    }
    
    function test_BidirectionalPeerConfiguration() public {
        // Configure BSC -> Arbitrum
        vm.prank(deployer);
        bscToken.setPeerAddress(ARBITRUM_EID, address(arbitrumToken));
        
        // Configure Arbitrum -> BSC
        vm.prank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, address(bscToken));
        
        // Verify both directions
        assertTrue(bscToken.hasPeer(ARBITRUM_EID));
        assertTrue(arbitrumToken.hasPeer(BSC_EID));
        
        assertEq(bscToken.getPeerAddress(ARBITRUM_EID), address(arbitrumToken));
        assertEq(arbitrumToken.getPeerAddress(BSC_EID), address(bscToken));
    }
    
    function test_SetPeer_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        arbitrumToken.setPeerAddress(BSC_EID, address(bscToken));
    }
    
    function test_SetPeer_Bytes32Format() public {
        bytes32 peerBytes = bytes32(uint256(uint160(address(bscToken))));
        
        vm.prank(deployer);
        arbitrumToken.setPeer(BSC_EID, peerBytes);
        
        assertEq(arbitrumToken.peers(BSC_EID), peerBytes);
    }
    
    function test_UpdateExistingPeer() public {
        // Set initial peer
        vm.prank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, address(bscToken));
        
        // Update to new address
        address newPeer = makeAddr("newPeer");
        vm.prank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, newPeer);
        
        assertEq(arbitrumToken.getPeerAddress(BSC_EID), newPeer);
    }
    
    function test_RemovePeer() public {
        // Set peer
        vm.prank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, address(bscToken));
        assertTrue(arbitrumToken.hasPeer(BSC_EID));
        
        // Remove peer (set to zero)
        vm.prank(deployer);
        arbitrumToken.setPeer(BSC_EID, bytes32(0));
        assertFalse(arbitrumToken.hasPeer(BSC_EID));
    }
    
    // ============ Multi-Peer Configuration Tests ============
    
    function test_ConfigureMultiplePeers() public {
        address baseToken = address(0xBA5EBA5EBA5EBA5EBA5EBA5EBA5EBA5EBA5EBA5E);
        
        vm.startPrank(deployer);
        
        // Set multiple peers on Arbitrum
        arbitrumToken.setPeerAddress(BSC_EID, address(bscToken));
        arbitrumToken.setPeerAddress(BASE_EID, baseToken);
        
        vm.stopPrank();
        
        assertTrue(arbitrumToken.hasPeer(BSC_EID));
        assertTrue(arbitrumToken.hasPeer(BASE_EID));
        assertEq(arbitrumToken.getPeerAddress(BSC_EID), address(bscToken));
        assertEq(arbitrumToken.getPeerAddress(BASE_EID), baseToken);
    }
    
    // ============ Cross-Chain Transfer Integration Tests ============
    
    function test_CrossChainTransferAfterPeerConfig() public {
        // Configure bidirectional peers
        vm.startPrank(deployer);
        bscToken.setPeerAddress(ARBITRUM_EID, address(arbitrumToken));
        arbitrumToken.setPeerAddress(BSC_EID, address(bscToken));
        vm.stopPrank();
        
        // Verify BSC can quote send to Arbitrum
        SendParam memory sendParam = SendParam({
            dstEid: ARBITRUM_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: 100 * 1e18,
            minAmountLD: 99 * 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        // This should not revert (peer is configured)
        MessagingFee memory fee = bscToken.quoteSend(sendParam, false);
        assertGt(fee.nativeFee, 0);
    }
    
    function test_CrossChainSendWithoutPeer_Reverts() public {
        // Don't configure peers - leave default
        
        SendParam memory sendParam = SendParam({
            dstEid: ARBITRUM_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: 100 * 1e18,
            minAmountLD: 99 * 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        // Should revert because no peer configured
        vm.expectRevert(abi.encodeWithSelector(LVGTokenOFT.NoPeer.selector, ARBITRUM_EID));
        bscToken.quoteSend(sendParam, false);
    }
    
    // ============ Rate Limit Configuration Tests ============
    
    function test_SetRateLimitsAfterDeployment() public {
        uint256 dailyLimit = 10_000_000 * 1e18; // 10M tokens per day
        uint256 window = 24 hours;
        
        vm.startPrank(deployer);
        
        // Set rate limits on Arbitrum for BSC transfers
        arbitrumToken.setRateLimit(BSC_EID, dailyLimit, window);
        
        // Set rate limits on BSC for Arbitrum transfers
        bscToken.setRateLimit(ARBITRUM_EID, dailyLimit, window);
        
        vm.stopPrank();
        
        // Verify
        (uint256 limit, uint256 w, , ) = arbitrumToken.getRateLimit(BSC_EID);
        assertEq(limit, dailyLimit);
        assertEq(w, window);
    }
    
    // ============ Minter Configuration Tests ============
    
    function test_AddMinterAfterDeployment() public {
        address stakingContract = address(0x57A4E57A4E57A4E57A4E57A4E57A4E57A4E57A4E);
        
        vm.prank(deployer);
        arbitrumToken.setMinter(stakingContract, true);
        
        assertTrue(arbitrumToken.isMinter(stakingContract));
        
        // Minter can mint
        vm.prank(stakingContract);
        arbitrumToken.mint(user1, 1000 * 1e18);
        
        assertEq(arbitrumToken.balanceOf(user1), 1000 * 1e18);
    }
    
    // ============ LayerZero Config Library Tests ============
    
    function test_LayerZeroConfigConstants() public pure {
        assertEq(LayerZeroConfig.LZ_ENDPOINT_V2, 0x1a44076050125825900e736c501f859c50fE728c);
        assertEq(LayerZeroConfig.EID_BSC, 30102);
        assertEq(LayerZeroConfig.EID_ARBITRUM, 30110);
        assertEq(LayerZeroConfig.EID_BASE, 30184);
    }
    
    function test_LayerZeroConfig_GetArbitrumConfig() public pure {
        LayerZeroConfig.ChainConfig memory config = LayerZeroConfig.getArbitrumConfig();
        
        assertEq(config.eid, 30110);
        assertEq(config.endpoint, 0x1a44076050125825900e736c501f859c50fE728c);
        assertEq(config.chainId, 42161);
        assertEq(keccak256(bytes(config.name)), keccak256(bytes("Arbitrum")));
    }
    
    function test_LayerZeroConfig_GetBSCConfig() public pure {
        LayerZeroConfig.ChainConfig memory config = LayerZeroConfig.getBSCConfig();
        
        assertEq(config.eid, 30102);
        assertEq(config.chainId, 56);
    }
    
    function test_LayerZeroConfig_AddressToBytes32() public pure {
        address testAddr = 0x1234567890AbcdEF1234567890aBcdef12345678;
        bytes32 result = LayerZeroConfig.addressToBytes32(testAddr);
        
        assertEq(result, bytes32(uint256(uint160(testAddr))));
    }
    
    function test_LayerZeroConfig_Bytes32ToAddress() public pure {
        address testAddr = 0x1234567890AbcdEF1234567890aBcdef12345678;
        bytes32 testBytes = bytes32(uint256(uint160(testAddr)));
        
        address result = LayerZeroConfig.bytes32ToAddress(testBytes);
        assertEq(result, testAddr);
    }
    
    function test_LayerZeroConfig_GetSupportedEids() public pure {
        uint32[] memory eids = LayerZeroConfig.getSupportedEids();
        
        assertEq(eids.length, 3);
        assertEq(eids[0], 30102); // BSC
        assertEq(eids[1], 30110); // Arbitrum
        assertEq(eids[2], 30184); // Base
    }
    
    function test_LayerZeroConfig_IsSupported() public pure {
        assertTrue(LayerZeroConfig.isSupported(30102)); // BSC
        assertTrue(LayerZeroConfig.isSupported(30110)); // Arbitrum
        assertTrue(LayerZeroConfig.isSupported(30184)); // Base
        assertFalse(LayerZeroConfig.isSupported(30109)); // Polygon - not in supported list
    }
    
    function test_LayerZeroConfig_GetChainName() public pure {
        assertEq(keccak256(bytes(LayerZeroConfig.getChainName(30102))), keccak256(bytes("BSC")));
        assertEq(keccak256(bytes(LayerZeroConfig.getChainName(30110))), keccak256(bytes("Arbitrum")));
        assertEq(keccak256(bytes(LayerZeroConfig.getChainName(30184))), keccak256(bytes("Base")));
        assertEq(keccak256(bytes(LayerZeroConfig.getChainName(99999))), keccak256(bytes("Unknown")));
    }
    
    // ============ Deployment Script Contract Tests ============
    
    function test_DeployArbitrumScript_Constants() public pure {
        DeployArbitrum script = new DeployArbitrum();
        
        assertEq(script.ARBITRUM_LZ_ENDPOINT(), 0x1a44076050125825900e736c501f859c50fE728c);
        assertEq(script.ARBITRUM_CHAIN_ID(), 42161);
        assertEq(script.ARBITRUM_EID(), 30110);
    }
    
    function test_ConfigurePeersScript_Constants() public pure {
        ConfigurePeers script = new ConfigurePeers();
        
        assertEq(script.BSC_CHAIN_ID(), 56);
        assertEq(script.ARBITRUM_CHAIN_ID(), 42161);
        assertEq(script.BSC_EID(), 30102);
        assertEq(script.ARBITRUM_EID(), 30110);
        assertEq(script.BASE_EID(), 30184);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_PeerAddressConversion(address peer) public {
        vm.assume(peer != address(0));
        
        bytes32 peerBytes = bytes32(uint256(uint160(peer)));
        
        vm.prank(deployer);
        arbitrumToken.setPeer(BSC_EID, peerBytes);
        
        assertEq(arbitrumToken.getPeerAddress(BSC_EID), peer);
    }
    
    function testFuzz_MultiplePeerConfigurations(
        address bscPeer,
        address basePeer
    ) public {
        vm.assume(bscPeer != address(0));
        vm.assume(basePeer != address(0));
        
        vm.startPrank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, bscPeer);
        arbitrumToken.setPeerAddress(BASE_EID, basePeer);
        vm.stopPrank();
        
        assertEq(arbitrumToken.getPeerAddress(BSC_EID), bscPeer);
        assertEq(arbitrumToken.getPeerAddress(BASE_EID), basePeer);
    }
    
    // ============ Edge Cases ============
    
    function test_ZeroAddressPeer() public {
        vm.prank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, address(0));
        
        // Zero address means no peer configured
        assertFalse(arbitrumToken.hasPeer(BSC_EID));
    }
    
    function test_SameAddressAsPeer() public {
        // Set token as its own peer (edge case, should work)
        vm.prank(deployer);
        arbitrumToken.setPeerAddress(BSC_EID, address(arbitrumToken));
        
        assertEq(arbitrumToken.getPeerAddress(BSC_EID), address(arbitrumToken));
    }
    
    receive() external payable {}
}
