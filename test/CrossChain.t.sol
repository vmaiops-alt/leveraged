// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/crosschain/LVGTokenOFT.sol";
import "../contracts/crosschain/interfaces/ILVGTokenOFT.sol";
// MessagingParams, MessagingReceipt, MessagingFee, Origin imported via LVGTokenOFT.sol

/**
 * @title Mock LayerZero Endpoint for testing
 */
contract MockLzEndpoint {
    address public delegate;
    
    struct SentMessage {
        uint32 dstEid;
        bytes32 receiver;
        bytes message;
        bytes options;
        uint256 nativeFee;
    }
    
    SentMessage[] public sentMessages;
    uint64 public nonce;
    
    function setDelegate(address _delegate) external {
        delegate = _delegate;
    }
    
    function quote(
        MessagingParams calldata /*_params*/,
        address /*_sender*/
    ) external pure returns (MessagingFee memory) {
        return MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
    }
    
    function send(
        MessagingParams calldata _params,
        address /*_refundAddress*/
    ) external payable returns (MessagingReceipt memory) {
        sentMessages.push(SentMessage({
            dstEid: _params.dstEid,
            receiver: _params.receiver,
            message: _params.message,
            options: _params.options,
            nativeFee: msg.value
        }));
        
        nonce++;
        
        return MessagingReceipt({
            guid: keccak256(abi.encodePacked(nonce, _params.dstEid, _params.receiver)),
            nonce: nonce,
            fee: MessagingFee({
                nativeFee: msg.value,
                lzTokenFee: 0
            })
        });
    }
    
    function getSentMessageCount() external view returns (uint256) {
        return sentMessages.length;
    }
    
    function getLastSentMessage() external view returns (SentMessage memory) {
        require(sentMessages.length > 0, "No messages sent");
        return sentMessages[sentMessages.length - 1];
    }
}

/**
 * @title LVGTokenOFT Tests
 * @notice Comprehensive unit tests for LayerZero V2 OFT token
 */
contract LVGTokenOFTTest is Test {
    LVGTokenOFT public token;
    MockLzEndpoint public mockEndpoint;
    
    address public owner = address(this);
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public minter = address(0x1003);
    
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    uint32 public constant BSC_EID = 30102;
    uint32 public constant ARB_EID = 30110;
    
    function setUp() public {
        // Deploy mock endpoint
        mockEndpoint = new MockLzEndpoint();
        
        // Deploy OFT token with initial supply
        token = new LVGTokenOFT(
            address(mockEndpoint),
            INITIAL_SUPPLY
        );
        
        // Grant minter role
        token.setMinter(minter, true);
        
        // Set up peer for BSC
        token.setPeer(BSC_EID, bytes32(uint256(uint160(address(0xBEEF)))));
    }
    
    // ============ Basic Token Tests ============
    
    function test_Name() public view {
        assertEq(token.name(), "Leveraged");
    }
    
    function test_Symbol() public view {
        assertEq(token.symbol(), "LVG");
    }
    
    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }
    
    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }
    
    function test_MaxSupply() public view {
        assertEq(token.MAX_SUPPLY(), 1_000_000_000 * 1e18);
    }
    
    // ============ Minting Tests ============
    
    function test_Mint() public {
        uint256 amount = 1000 * 1e18;
        
        vm.prank(minter);
        token.mint(user1, amount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }
    
    function test_Mint_OnlyMinter() public {
        vm.prank(user1);
        vm.expectRevert(ILVGTokenOFT.NotMinter.selector);
        token.mint(user1, 1000 * 1e18);
    }
    
    function test_Mint_ExceedsCap() public {
        uint256 cap = token.MAX_SUPPLY();
        uint256 remaining = cap - token.totalSupply();
        
        vm.prank(minter);
        vm.expectRevert(ILVGTokenOFT.ExceedsMaxSupply.selector);
        token.mint(user1, remaining + 1);
    }
    
    function test_Mint_ZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(ILVGTokenOFT.ZeroAmount.selector);
        token.mint(user1, 0);
    }
    
    function test_Mint_ZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(ILVGTokenOFT.InvalidRecipient.selector);
        token.mint(address(0), 1000 * 1e18);
    }
    
    function test_Mint_MultipleTimes() public {
        vm.prank(minter);
        token.mint(user1, 100 * 1e18);
        
        vm.prank(minter);
        token.mint(user2, 200 * 1e18);
        
        assertEq(token.balanceOf(user1), 100 * 1e18);
        assertEq(token.balanceOf(user2), 200 * 1e18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 300 * 1e18);
    }
    
    // ============ Burning Tests ============
    
    function test_Burn() public {
        uint256 burnAmount = 400 * 1e18;
        uint256 initialBalance = token.balanceOf(owner);
        
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(owner), initialBalance - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }
    
    function test_Burn_ZeroAmount() public {
        vm.expectRevert(ILVGTokenOFT.ZeroAmount.selector);
        token.burn(0);
    }
    
    function test_Burn_InsufficientBalance() public {
        vm.prank(user1); // user1 has no tokens
        vm.expectRevert();
        token.burn(100 * 1e18);
    }
    
    function test_BurnFrom() public {
        uint256 burnAmount = 100 * 1e18;
        
        token.approve(user1, burnAmount);
        
        vm.prank(user1);
        token.burnFrom(owner, burnAmount);
        
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }
    
    // ============ Transfer Tests ============
    
    function test_Transfer() public {
        uint256 amount = 1000 * 1e18;
        
        token.transfer(user1, amount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
    }
    
    function test_TransferFrom() public {
        uint256 amount = 500 * 1e18;
        
        token.approve(user1, amount);
        
        vm.prank(user1);
        token.transferFrom(owner, user2, amount);
        
        assertEq(token.balanceOf(user2), amount);
        assertEq(token.allowance(owner, user1), 0);
    }
    
    // ============ Minter Management Tests ============
    
    function test_SetMinter() public {
        address newMinter = address(0x999);
        
        assertFalse(token.isMinter(newMinter));
        
        token.setMinter(newMinter, true);
        
        assertTrue(token.isMinter(newMinter));
        
        // New minter can mint
        vm.prank(newMinter);
        token.mint(user1, 100 * 1e18);
        assertEq(token.balanceOf(user1), 100 * 1e18);
    }
    
    function test_SetMinter_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.setMinter(user1, true);
    }
    
    function test_RevokeMinter() public {
        token.setMinter(minter, false);
        
        assertFalse(token.isMinter(minter));
        
        vm.prank(minter);
        vm.expectRevert(ILVGTokenOFT.NotMinter.selector);
        token.mint(user1, 100 * 1e18);
    }
    
    // ============ Peer Management Tests ============
    
    function test_SetPeer() public {
        bytes32 peerAddress = bytes32(uint256(uint160(address(0xCAFE))));
        
        token.setPeer(ARB_EID, peerAddress);
        
        assertTrue(token.hasPeer(ARB_EID));
        assertEq(token.peers(ARB_EID), peerAddress);
    }
    
    function test_SetPeerAddress() public {
        address peerAddress = address(0xCAFE);
        
        token.setPeerAddress(ARB_EID, peerAddress);
        
        assertTrue(token.hasPeer(ARB_EID));
        assertEq(token.getPeerAddress(ARB_EID), peerAddress);
    }
    
    function test_SetPeer_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.setPeer(ARB_EID, bytes32(uint256(1)));
    }
    
    // ============ Rate Limiting Tests ============
    
    function test_SetRateLimit() public {
        uint256 limit = 1000 * 1e18;
        uint256 window = 1 hours;
        
        token.setRateLimit(BSC_EID, limit, window);
        
        (uint256 l, uint256 w, , ) = token.getRateLimit(BSC_EID);
        assertEq(l, limit);
        assertEq(w, window);
    }
    
    function test_AvailableRateLimit_NoLimit() public view {
        // ARB has no limit set
        uint256 available = token.availableRateLimit(ARB_EID);
        assertEq(available, type(uint256).max);
    }
    
    function test_AvailableRateLimit_WithLimit() public {
        uint256 limit = 1000 * 1e18;
        token.setRateLimit(BSC_EID, limit, 1 hours);
        
        uint256 available = token.availableRateLimit(BSC_EID);
        assertEq(available, limit);
    }
    
    // ============ OFT Interface Tests ============
    
    function test_OftVersion() public view {
        (bytes4 interfaceId, uint64 version) = token.oftVersion();
        assertEq(version, 1);
        assertTrue(interfaceId != bytes4(0));
    }
    
    function test_Token() public view {
        assertEq(token.token(), address(token));
    }
    
    function test_ApprovalRequired() public view {
        assertFalse(token.approvalRequired());
    }
    
    function test_SharedDecimals() public view {
        assertEq(token.sharedDecimals(), 6);
    }
    
    function test_GetEndpointIds() public view {
        (uint32 bsc, uint32 arb, uint32 base, uint32 poly, uint32 opt, uint32 eth) = token.getEndpointIds();
        
        assertEq(bsc, 30102);
        assertEq(arb, 30110);
        assertEq(base, 30184);
        assertEq(poly, 30109);
        assertEq(opt, 30111);
        assertEq(eth, 30101);
    }
    
    // ============ Cross-Chain Send Tests ============
    
    function test_QuoteSend() public view {
        SendParam memory sendParam = SendParam({
            dstEid: BSC_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: 100 * 1e18,
            minAmountLD: 99 * 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        MessagingFee memory fee = token.quoteSend(sendParam, false);
        assertEq(fee.nativeFee, 0.001 ether);
    }
    
    function test_Send() public {
        uint256 amount = 100 * 1e18;
        uint256 initialBalance = token.balanceOf(owner);
        
        SendParam memory sendParam = SendParam({
            dstEid: BSC_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: amount,
            minAmountLD: amount * 99 / 100,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        MessagingFee memory fee = MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
        
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = 
            token.send{value: 0.001 ether}(sendParam, fee, owner);
        
        // Check tokens were burned
        assertEq(token.balanceOf(owner), initialBalance - amount);
        
        // Check receipt
        assertEq(oftReceipt.amountSentLD, amount);
        assertEq(oftReceipt.amountReceivedLD, amount);
        assertTrue(msgReceipt.guid != bytes32(0));
        
        // Check message was sent to endpoint
        assertEq(mockEndpoint.getSentMessageCount(), 1);
    }
    
    function test_Send_NoPeer() public {
        SendParam memory sendParam = SendParam({
            dstEid: ARB_EID, // No peer set
            to: bytes32(uint256(uint160(user1))),
            amountLD: 100 * 1e18,
            minAmountLD: 99 * 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        MessagingFee memory fee = MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
        
        vm.expectRevert(abi.encodeWithSelector(LVGTokenOFT.NoPeer.selector, ARB_EID));
        token.send{value: 0.001 ether}(sendParam, fee, owner);
    }
    
    function test_SendTokens() public {
        uint256 amount = 50 * 1e18;
        uint256 initialBalance = token.balanceOf(owner);
        
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = 
            token.sendTokens{value: 0.001 ether}(BSC_EID, user1, amount);
        
        assertEq(token.balanceOf(owner), initialBalance - amount);
        assertEq(oftReceipt.amountSentLD, amount);
        assertTrue(msgReceipt.guid != bytes32(0));
    }
    
    // ============ Cross-Chain Receive Tests ============
    
    function test_LzReceive() public {
        // Set peer for source chain
        bytes32 sourcePeer = bytes32(uint256(uint160(address(0xCAFE))));
        token.setPeer(ARB_EID, sourcePeer);
        
        // Encode message: recipient + amount in shared decimals
        uint64 amountSD = 100 * 1e6; // 100 tokens in 6 decimals
        bytes memory message = abi.encodePacked(
            bytes32(uint256(uint160(user1))),
            amountSD
        );
        
        Origin memory origin = Origin({
            srcEid: ARB_EID,
            sender: sourcePeer,
            nonce: 1
        });
        
        // Call lzReceive from endpoint
        vm.prank(address(mockEndpoint));
        token.lzReceive(origin, bytes32(0), message, address(0), bytes(""));
        
        // Check tokens were minted
        uint256 expectedAmount = uint256(amountSD) * 1e12; // Convert to 18 decimals
        assertEq(token.balanceOf(user1), expectedAmount);
    }
    
    function test_LzReceive_OnlyEndpoint() public {
        Origin memory origin = Origin({
            srcEid: ARB_EID,
            sender: bytes32(0),
            nonce: 1
        });
        
        vm.prank(user1);
        vm.expectRevert(LVGTokenOFT.OnlyEndpoint.selector);
        token.lzReceive(origin, bytes32(0), bytes(""), address(0), bytes(""));
    }
    
    function test_LzReceive_OnlyPeer() public {
        bytes32 untrustedSender = bytes32(uint256(uint160(address(0xBAD))));
        
        Origin memory origin = Origin({
            srcEid: ARB_EID,
            sender: untrustedSender,
            nonce: 1
        });
        
        vm.prank(address(mockEndpoint));
        vm.expectRevert(abi.encodeWithSelector(
            LVGTokenOFT.OnlyPeer.selector,
            ARB_EID,
            untrustedSender
        ));
        token.lzReceive(origin, bytes32(0), bytes(""), address(0), bytes(""));
    }
    
    // ============ Rate Limit Send Tests ============
    
    function test_Send_RateLimitExceeded() public {
        // Set rate limit
        uint256 limit = 50 * 1e18;
        token.setRateLimit(BSC_EID, limit, 1 hours);
        
        // Try to send more than limit
        SendParam memory sendParam = SendParam({
            dstEid: BSC_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: 100 * 1e18,
            minAmountLD: 99 * 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        MessagingFee memory fee = MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
        
        vm.expectRevert(abi.encodeWithSelector(
            ILVGTokenOFT.RateLimitExceeded.selector,
            BSC_EID,
            100 * 1e18,
            limit
        ));
        token.send{value: 0.001 ether}(sendParam, fee, owner);
    }
    
    function test_Send_RateLimitResets() public {
        // Set rate limit
        uint256 limit = 50 * 1e18;
        token.setRateLimit(BSC_EID, limit, 1 hours);
        
        // Send within limit
        SendParam memory sendParam = SendParam({
            dstEid: BSC_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: limit,
            minAmountLD: limit * 99 / 100,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        MessagingFee memory fee = MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
        
        token.send{value: 0.001 ether}(sendParam, fee, owner);
        
        // Check limit used
        assertEq(token.availableRateLimit(BSC_EID), 0);
        
        // Advance time past window
        vm.warp(block.timestamp + 1 hours + 1);
        
        // Limit should be reset
        assertEq(token.availableRateLimit(BSC_EID), limit);
        
        // Should be able to send again
        token.send{value: 0.001 ether}(sendParam, fee, owner);
    }
    
    // ============ Dust Removal Tests ============
    
    function test_DustRemoval() public {
        // Amount with dust (less than 10^12 is dust)
        uint256 amountWithDust = 100 * 1e18 + 12345;
        uint256 expectedAmount = 100 * 1e18; // Dust removed
        
        SendParam memory sendParam = SendParam({
            dstEid: BSC_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: amountWithDust,
            minAmountLD: 99 * 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        MessagingFee memory fee = MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
        
        uint256 initialBalance = token.balanceOf(owner);
        
        (, OFTReceipt memory oftReceipt) = 
            token.send{value: 0.001 ether}(sendParam, fee, owner);
        
        // Check dust was removed
        assertEq(oftReceipt.amountSentLD, expectedAmount);
        assertEq(token.balanceOf(owner), initialBalance - expectedAmount);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= token.MAX_SUPPLY() - token.totalSupply());
        
        vm.prank(minter);
        token.mint(to, amount);
        
        assertEq(token.balanceOf(to), amount);
    }
    
    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != owner);
        vm.assume(amount > 0);
        vm.assume(amount <= token.balanceOf(owner));
        
        token.transfer(to, amount);
        
        assertEq(token.balanceOf(to), amount);
    }
    
    // ============ Integration Tests ============
    
    function test_FullCrossChainFlow() public {
        // 1. Set up peer on both "chains" (simulated)
        bytes32 peerAddress = bytes32(uint256(uint160(address(token))));
        token.setPeer(ARB_EID, peerAddress);
        
        uint256 amount = 100 * 1e18;
        uint256 initialSupply = token.totalSupply();
        
        // 2. Send tokens (burns on source)
        SendParam memory sendParam = SendParam({
            dstEid: ARB_EID,
            to: bytes32(uint256(uint160(user1))),
            amountLD: amount,
            minAmountLD: amount * 99 / 100,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        
        MessagingFee memory fee = MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
        
        token.send{value: 0.001 ether}(sendParam, fee, owner);
        
        // Check tokens were burned
        assertEq(token.totalSupply(), initialSupply - amount);
        
        // 3. Simulate receive on destination (mints)
        uint64 amountSD = uint64(amount / 1e12);
        bytes memory message = abi.encodePacked(
            bytes32(uint256(uint160(user1))),
            amountSD
        );
        
        Origin memory origin = Origin({
            srcEid: ARB_EID,
            sender: peerAddress,
            nonce: 1
        });
        
        vm.prank(address(mockEndpoint));
        token.lzReceive(origin, bytes32(0), message, address(0), bytes(""));
        
        // Check tokens were minted to recipient
        assertEq(token.balanceOf(user1), amount);
        
        // Total supply back to original (burned + minted = 0 net change)
        assertEq(token.totalSupply(), initialSupply);
    }
    
    // ============ Edge Cases ============
    
    function test_MaxSupplyMint() public {
        // Burn existing supply to make room
        token.burn(token.balanceOf(owner));
        
        // Mint exactly max supply
        uint256 maxSupply = token.MAX_SUPPLY();
        vm.prank(minter);
        token.mint(user1, maxSupply);
        
        assertEq(token.totalSupply(), maxSupply);
        
        // Can't mint more
        vm.prank(minter);
        vm.expectRevert(ILVGTokenOFT.ExceedsMaxSupply.selector);
        token.mint(user2, 1);
    }
    
    function test_AllowInitializePath() public {
        bytes32 trustedPeer = bytes32(uint256(uint160(address(0xCAFE))));
        token.setPeer(ARB_EID, trustedPeer);
        
        Origin memory validOrigin = Origin({
            srcEid: ARB_EID,
            sender: trustedPeer,
            nonce: 1
        });
        
        assertTrue(token.allowInitializePath(validOrigin));
        
        Origin memory invalidOrigin = Origin({
            srcEid: ARB_EID,
            sender: bytes32(uint256(1)),
            nonce: 1
        });
        
        assertFalse(token.allowInitializePath(invalidOrigin));
    }
    
    receive() external payable {}
}
