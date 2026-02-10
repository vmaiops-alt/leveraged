// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/crosschain/LVGTokenOFT.sol";

/**
 * @title LVGTokenOFT Tests
 * @notice Unit tests for LayerZero OFT token
 */
contract LVGTokenOFTTest is Test {
    LVGTokenOFT public token;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public minter = address(0x4);
    address public mockEndpoint = address(0x1234);
    
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    
    function setUp() public {
        vm.prank(owner);
        token = new LVGTokenOFT(
            mockEndpoint,
            0 // No initial supply
        );
        
        // Grant minter role
        vm.prank(owner);
        token.setMinter(minter, true);
    }
    
    // ============ Basic Token Tests ============
    
    function test_Name() public view {
        assertEq(token.name(), "LEVERAGED");
    }
    
    function test_Symbol() public view {
        assertEq(token.symbol(), "LVG");
    }
    
    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }
    
    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 0);
    }
    
    // ============ Minting Tests ============
    
    function test_Mint() public {
        uint256 amount = 1000 * 1e18;
        
        vm.prank(minter);
        token.mint(user1, amount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }
    
    function test_Mint_OnlyMinter() public {
        vm.prank(user1);
        vm.expectRevert(LVGTokenOFT.NotMinter.selector);
        token.mint(user1, 1000 * 1e18);
    }
    
    function test_Mint_ExceedsCap() public {
        uint256 cap = token.MAX_SUPPLY();
        
        vm.prank(minter);
        vm.expectRevert(LVGTokenOFT.ExceedsMaxSupply.selector);
        token.mint(user1, cap + 1);
    }
    
    function test_Mint_MultipleTimes() public {
        vm.prank(minter);
        token.mint(user1, 100 * 1e18);
        
        vm.prank(minter);
        token.mint(user2, 200 * 1e18);
        
        assertEq(token.balanceOf(user1), 100 * 1e18);
        assertEq(token.balanceOf(user2), 200 * 1e18);
        assertEq(token.totalSupply(), 300 * 1e18);
    }
    
    // ============ Burning Tests ============
    
    function test_Burn() public {
        uint256 mintAmount = 1000 * 1e18;
        uint256 burnAmount = 400 * 1e18;
        
        vm.prank(minter);
        token.mint(user1, mintAmount);
        
        vm.prank(user1);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }
    
    function test_Burn_InsufficientBalance() public {
        vm.prank(minter);
        token.mint(user1, 100 * 1e18);
        
        vm.prank(user1);
        vm.expectRevert();
        token.burn(200 * 1e18);
    }
    
    // ============ Transfer Tests ============
    
    function test_Transfer() public {
        uint256 amount = 1000 * 1e18;
        
        vm.prank(minter);
        token.mint(user1, amount);
        
        vm.prank(user1);
        token.transfer(user2, 400 * 1e18);
        
        assertEq(token.balanceOf(user1), 600 * 1e18);
        assertEq(token.balanceOf(user2), 400 * 1e18);
    }
    
    function test_TransferFrom() public {
        uint256 amount = 1000 * 1e18;
        
        vm.prank(minter);
        token.mint(user1, amount);
        
        vm.prank(user1);
        token.approve(user2, 500 * 1e18);
        
        vm.prank(user2);
        token.transferFrom(user1, user2, 400 * 1e18);
        
        assertEq(token.balanceOf(user1), 600 * 1e18);
        assertEq(token.balanceOf(user2), 400 * 1e18);
        assertEq(token.allowance(user1, user2), 100 * 1e18);
    }
    
    // ============ Minter Management Tests ============
    
    function test_SetMinter() public {
        address newMinter = address(0x999);
        
        assertFalse(token.minters(newMinter));
        
        vm.prank(owner);
        token.setMinter(newMinter, true);
        
        assertTrue(token.minters(newMinter));
        
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
        vm.prank(owner);
        token.setMinter(minter, false);
        
        assertFalse(token.minters(minter));
        
        vm.prank(minter);
        vm.expectRevert(LVGTokenOFT.NotMinter.selector);
        token.mint(user1, 100 * 1e18);
    }
    
    // ============ Max Supply Tests ============
    
    function test_MaxSupply() public view {
        assertEq(token.MAX_SUPPLY(), 1_000_000_000 * 1e18); // 1 billion
    }
    
    function test_MintUpToMaxSupply() public {
        uint256 maxSupply = token.MAX_SUPPLY();
        
        // Mint exactly max supply
        vm.prank(minter);
        token.mint(user1, maxSupply);
        
        assertEq(token.totalSupply(), maxSupply);
        
        // Can't mint more
        vm.prank(minter);
        vm.expectRevert(LVGTokenOFT.ExceedsMaxSupply.selector);
        token.mint(user2, 1);
    }
    
    // ============ OFT Placeholder Tests ============
    // Note: Full OFT tests require LayerZero endpoint mock
    
    function test_EndpointSet() public view {
        assertEq(token.lzEndpoint(), mockEndpoint);
    }
    
    // ============ Edge Cases ============
    
    function test_MintToZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert();
        token.mint(address(0), 100 * 1e18);
    }
    
    function test_TransferToZeroAddress() public {
        vm.prank(minter);
        token.mint(user1, 100 * 1e18);
        
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(address(0), 50 * 1e18);
    }
    
    function test_ZeroAmountMint() public {
        vm.prank(minter);
        token.mint(user1, 0);
        
        assertEq(token.balanceOf(user1), 0);
    }
    
    function test_ZeroAmountTransfer() public {
        vm.prank(minter);
        token.mint(user1, 100 * 1e18);
        
        vm.prank(user1);
        token.transfer(user2, 0);
        
        assertEq(token.balanceOf(user1), 100 * 1e18);
        assertEq(token.balanceOf(user2), 0);
    }
}
