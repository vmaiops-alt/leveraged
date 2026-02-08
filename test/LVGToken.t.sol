// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/token/LVGToken.sol";

/**
 * @title LVGTokenTest
 * @notice Unit tests for LVGToken
 */
contract LVGTokenTest is Test {
    
    LVGToken public token;
    
    address public owner = address(this);
    address public minter = address(0x100);
    address public team = address(0x1);
    address public treasury = address(0x2);
    address public liquidity = address(0x3);
    address public privateSale = address(0x4);
    address public airdrop = address(0x5);
    address public user = address(0x6);
    
    function setUp() public {
        token = new LVGToken();
    }
    
    // ============ Initial State Tests ============
    
    function test_InitialState() public view {
        assertEq(token.name(), "Leveraged");
        assertEq(token.symbol(), "LVG");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.owner(), owner);
        assertEq(token.MAX_SUPPLY(), 100_000_000 * 1e18);
    }
    
    // ============ Initial Distribution Tests ============
    
    function test_InitialDistribution() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        
        assertEq(token.balanceOf(team), 15_000_000 * 1e18);
        assertEq(token.balanceOf(treasury), 20_000_000 * 1e18);
        assertEq(token.balanceOf(liquidity), 10_000_000 * 1e18);
        assertEq(token.balanceOf(privateSale), 10_000_000 * 1e18);
        assertEq(token.balanceOf(airdrop), 5_000_000 * 1e18);
        
        // Total: 60% distributed, 40% reserved for farming
        assertEq(token.totalSupply(), 60_000_000 * 1e18);
        assertTrue(token.initialDistributionDone());
    }
    
    function test_InitialDistribution_OnlyOnce() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        
        vm.expectRevert("Already distributed");
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
    }
    
    function test_InitialDistribution_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("Not owner");
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
    }
    
    function test_InitialDistribution_InvalidAddresses() public {
        vm.expectRevert("Invalid addresses");
        token.initialDistribution(address(0), treasury, liquidity, privateSale, airdrop);
    }
    
    // ============ Minting Tests ============
    
    function test_SetMinter() public {
        token.setMinter(minter);
        assertEq(token.minter(), minter);
    }
    
    function test_SetMinter_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert("Not owner");
        token.setMinter(minter);
    }
    
    function test_MintFarmingRewards() public {
        token.setMinter(minter);
        
        uint256 mintAmount = 1000 * 1e18;
        
        vm.prank(minter);
        token.mintFarmingRewards(user, mintAmount);
        
        assertEq(token.balanceOf(user), mintAmount);
        assertEq(token.farmingMinted(), mintAmount);
    }
    
    function test_MintFarmingRewards_CapExceeded() public {
        token.setMinter(minter);
        
        // Try to mint more than farming allocation
        uint256 excessAmount = 41_000_000 * 1e18; // More than 40M
        
        vm.prank(minter);
        vm.expectRevert("Farming cap exceeded");
        token.mintFarmingRewards(user, excessAmount);
    }
    
    function test_MintFarmingRewards_OnlyMinter() public {
        vm.prank(user);
        vm.expectRevert("Not minter");
        token.mintFarmingRewards(user, 1000 * 1e18);
    }
    
    function test_RemainingFarmingRewards() public {
        token.setMinter(minter);
        
        uint256 initial = token.remainingFarmingRewards();
        assertEq(initial, 40_000_000 * 1e18);
        
        vm.prank(minter);
        token.mintFarmingRewards(user, 1_000_000 * 1e18);
        
        assertEq(token.remainingFarmingRewards(), 39_000_000 * 1e18);
    }
    
    // ============ Burning Tests ============
    
    function test_Burn() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        
        uint256 burnAmount = 1000 * 1e18;
        uint256 balanceBefore = token.balanceOf(team);
        uint256 supplyBefore = token.totalSupply();
        
        vm.prank(team);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(team), balanceBefore - burnAmount);
        assertEq(token.totalSupply(), supplyBefore - burnAmount);
    }
    
    function test_Burn_InsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert("Insufficient balance");
        token.burn(1000 * 1e18);
    }
    
    function test_BurnFrom() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        
        uint256 burnAmount = 1000 * 1e18;
        
        // Team approves user to burn
        vm.prank(team);
        token.approve(user, burnAmount);
        
        uint256 balanceBefore = token.balanceOf(team);
        
        vm.prank(user);
        token.burnFrom(team, burnAmount);
        
        assertEq(token.balanceOf(team), balanceBefore - burnAmount);
    }
    
    // ============ ERC-20 Tests ============
    
    function test_Transfer() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        
        uint256 transferAmount = 100 * 1e18;
        
        vm.prank(team);
        token.transfer(user, transferAmount);
        
        assertEq(token.balanceOf(user), transferAmount);
    }
    
    function test_Transfer_InsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert("Insufficient balance");
        token.transfer(team, 100 * 1e18);
    }
    
    function test_Approve() public {
        uint256 approveAmount = 500 * 1e18;
        
        vm.prank(team);
        token.approve(user, approveAmount);
        
        assertEq(token.allowance(team, user), approveAmount);
    }
    
    function test_TransferFrom() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        
        uint256 amount = 100 * 1e18;
        
        vm.prank(team);
        token.approve(user, amount);
        
        vm.prank(user);
        token.transferFrom(team, user, amount);
        
        assertEq(token.balanceOf(user), amount);
        assertEq(token.allowance(team, user), 0);
    }
    
    function test_TransferFrom_InsufficientAllowance() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        
        vm.prank(user);
        vm.expectRevert("Insufficient allowance");
        token.transferFrom(team, user, 100 * 1e18);
    }
    
    // ============ Supply Cap Tests ============
    
    function test_MaxSupplyEnforced() public {
        token.initialDistribution(team, treasury, liquidity, privateSale, airdrop);
        token.setMinter(minter);
        
        // Mint all farming rewards
        vm.prank(minter);
        token.mintFarmingRewards(user, 40_000_000 * 1e18);
        
        // Total should now be MAX_SUPPLY
        assertEq(token.totalSupply(), 100_000_000 * 1e18);
        
        // Can't mint more
        vm.prank(minter);
        vm.expectRevert("Farming cap exceeded");
        token.mintFarmingRewards(user, 1);
    }
    
    // ============ Emission Rate Tests ============
    
    function test_FarmingEmissionRate() public view {
        uint256 rate = token.getFarmingEmissionRate();
        
        // 40M tokens over 4 years - approx 317 tokens/second
        uint256 fourYears = 4 * 365 days;
        uint256 totalTokens = 40_000_000 * 1e18;
        uint256 expected = totalTokens / fourYears;
        assertApproxEqAbs(rate, expected, 1e10); // small rounding tolerance
    }
}
