// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/core/FeeCollector.sol";

/**
 * @title FeeCollectorTest
 * @notice Unit tests for FeeCollector contract
 */
contract FeeCollectorTest is Test {
    
    FeeCollector public feeCollector;
    MockERC20 public usdt;
    MockERC20 public usdc;
    
    address public owner = address(this);
    address public vault = address(0x100);
    address public treasury = address(0x200);
    address public insuranceFund = address(0x300);
    address public stakingContract = address(0x400);
    
    uint256 constant INITIAL_BALANCE = 100_000 * 1e6; // 6 decimals like USDT
    
    function setUp() public {
        // Deploy mock tokens
        usdt = new MockERC20("USDT", "USDT", 6);
        usdc = new MockERC20("USDC", "USDC", 6);
        
        // Deploy fee collector
        feeCollector = new FeeCollector(treasury, insuranceFund, stakingContract);
        
        // Configure
        feeCollector.setVault(vault);
        feeCollector.addSupportedToken(address(usdt));
        feeCollector.addSupportedToken(address(usdc));
        
        // Mint tokens to fee collector (simulating collected fees)
        usdt.mint(address(feeCollector), INITIAL_BALANCE);
    }
    
    // ============ Configuration Tests ============
    
    function test_InitialConfig() public view {
        assertEq(feeCollector.treasury(), treasury);
        assertEq(feeCollector.insuranceFund(), insuranceFund);
        assertEq(feeCollector.stakingContract(), stakingContract);
        
        (uint256 treasuryRatio, uint256 insuranceRatio, uint256 stakerRatio) = feeCollector.getFeeRatios();
        assertEq(treasuryRatio, 5000);  // 50%
        assertEq(insuranceRatio, 3000); // 30%
        assertEq(stakerRatio, 2000);    // 20%
    }
    
    function test_SetFeeRatios() public {
        feeCollector.setFeeRatios(6000, 2500, 1500);
        
        (uint256 treasuryRatio, uint256 insuranceRatio, uint256 stakerRatio) = feeCollector.getFeeRatios();
        assertEq(treasuryRatio, 6000);
        assertEq(insuranceRatio, 2500);
        assertEq(stakerRatio, 1500);
    }
    
    function test_SetFeeRatios_InvalidSum() public {
        vm.expectRevert("Ratios must sum to 10000");
        feeCollector.setFeeRatios(5000, 3000, 3000); // Sums to 11000
    }
    
    function test_SetTreasury() public {
        address newTreasury = address(0x500);
        feeCollector.setTreasury(newTreasury);
        assertEq(feeCollector.treasury(), newTreasury);
    }
    
    function test_SetTreasury_Invalid() public {
        vm.expectRevert("Invalid treasury");
        feeCollector.setTreasury(address(0));
    }
    
    // ============ Token Support Tests ============
    
    function test_AddSupportedToken() public {
        MockERC20 newToken = new MockERC20("DAI", "DAI", 18);
        feeCollector.addSupportedToken(address(newToken));
        
        address[] memory tokens = feeCollector.getSupportedTokens();
        assertEq(tokens.length, 3);
    }
    
    function test_AddSupportedToken_Duplicate() public {
        vm.expectRevert("Already supported");
        feeCollector.addSupportedToken(address(usdt));
    }
    
    function test_RemoveSupportedToken() public {
        feeCollector.removeSupportedToken(address(usdc));
        
        address[] memory tokens = feeCollector.getSupportedTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(usdt));
    }
    
    // ============ Fee Collection Tests ============
    
    function test_CollectFees() public {
        uint256 feeAmount = 1000 * 1e6;
        
        // Mint tokens to vault
        usdt.mint(vault, feeAmount);
        
        // Approve fee collector
        vm.prank(vault);
        usdt.approve(address(feeCollector), feeAmount);
        
        // Collect fees
        vm.prank(vault);
        feeCollector.collectFees(address(usdt), feeAmount, "valueIncrease");
        
        assertEq(feeCollector.getPendingFees(address(usdt)), INITIAL_BALANCE + feeAmount);
    }
    
    function test_CollectFees_NotVault() public {
        vm.prank(address(0x999));
        vm.expectRevert("Not vault");
        feeCollector.collectFees(address(usdt), 1000 * 1e6, "test");
    }
    
    function test_CollectFees_UnsupportedToken() public {
        MockERC20 unsupported = new MockERC20("XXX", "XXX", 18);
        
        vm.prank(vault);
        vm.expectRevert("Token not supported");
        feeCollector.collectFees(address(unsupported), 1000, "test");
    }
    
    // ============ Distribution Tests ============
    
    function test_DistributeFeesForToken() public {
        // Set pending fees
        feeCollector.addSupportedToken(address(usdt)); // Already added, but we need pending fees
        
        // Record pending (simulating vault transfer)
        vm.prank(vault);
        feeCollector.collectFees(address(usdt), 0, "test"); // Just to set up
        
        // Actually mint fees to collector
        uint256 feeAmount = 1000 * 1e6;
        usdt.mint(address(feeCollector), feeAmount);
        
        // Manually set pending (would normally happen via collectFees)
        // For testing, we'll use the initial balance
        
        uint256 treasuryBefore = usdt.balanceOf(treasury);
        uint256 insuranceBefore = usdt.balanceOf(insuranceFund);
        uint256 stakingBefore = usdt.balanceOf(stakingContract);
        
        feeCollector.distributeToken(address(usdt));
        
        uint256 treasuryAfter = usdt.balanceOf(treasury);
        uint256 insuranceAfter = usdt.balanceOf(insuranceFund);
        uint256 stakingAfter = usdt.balanceOf(stakingContract);
        
        // Check distribution (50/30/20)
        assertEq(treasuryAfter - treasuryBefore, INITIAL_BALANCE * 5000 / 10000);
        assertEq(insuranceAfter - insuranceBefore, INITIAL_BALANCE * 3000 / 10000);
        // Stakers get remainder
        assertTrue(stakingAfter > stakingBefore);
    }
    
    function test_DistributeToken_BelowMinimum() public {
        // Set a small pending amount
        usdt.mint(address(feeCollector), 10 * 1e6); // Only 10 USDT
        
        // Clear existing pending
        feeCollector.emergencyWithdraw(address(usdt), owner);
        
        // Add back small amount
        usdt.mint(address(feeCollector), 10 * 1e6);
        
        vm.expectRevert("Below minimum");
        feeCollector.distributeToken(address(usdt));
    }
    
    // ============ Preview Distribution Tests ============
    
    function test_PreviewDistribution() public {
        (uint256 toTreasury, uint256 toInsurance, uint256 toStakers) = 
            feeCollector.previewDistribution(address(usdt));
        
        // 50/30/20 split of INITIAL_BALANCE
        assertEq(toTreasury, INITIAL_BALANCE * 5000 / 10000);
        assertEq(toInsurance, INITIAL_BALANCE * 3000 / 10000);
        assertEq(toStakers, INITIAL_BALANCE - toTreasury - toInsurance);
    }
    
    function test_PreviewDistribution_NoPending() public {
        feeCollector.emergencyWithdraw(address(usdt), owner);
        
        (uint256 toTreasury, uint256 toInsurance, uint256 toStakers) = 
            feeCollector.previewDistribution(address(usdt));
        
        assertEq(toTreasury, 0);
        assertEq(toInsurance, 0);
        assertEq(toStakers, 0);
    }
    
    // ============ Fee Type Tracking Tests ============
    
    function test_FeeTypeTracking() public {
        uint256 feeAmount = 500 * 1e6;
        
        usdt.mint(vault, feeAmount * 3);
        vm.startPrank(vault);
        usdt.approve(address(feeCollector), feeAmount * 3);
        
        feeCollector.collectFees(address(usdt), feeAmount, "valueIncrease");
        feeCollector.collectFees(address(usdt), feeAmount, "performance");
        feeCollector.collectFees(address(usdt), feeAmount, "entry");
        vm.stopPrank();
        
        assertEq(feeCollector.getTotalFeesByType("valueIncrease"), feeAmount);
        assertEq(feeCollector.getTotalFeesByType("performance"), feeAmount);
        assertEq(feeCollector.getTotalFeesByType("entry"), feeAmount);
    }
    
    // ============ Emergency Withdraw Tests ============
    
    function test_EmergencyWithdraw() public {
        uint256 balanceBefore = usdt.balanceOf(owner);
        
        feeCollector.emergencyWithdraw(address(usdt), owner);
        
        uint256 balanceAfter = usdt.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, INITIAL_BALANCE);
        assertEq(feeCollector.getPendingFees(address(usdt)), 0);
    }
    
    function test_EmergencyWithdraw_NotOwner() public {
        vm.prank(address(0x999));
        vm.expectRevert("Not owner");
        feeCollector.emergencyWithdraw(address(usdt), address(0x999));
    }
    
    // ============ Pause Tests ============
    
    function test_Pause() public {
        feeCollector.pause();
        
        vm.prank(vault);
        vm.expectRevert("Paused");
        feeCollector.collectFees(address(usdt), 100 * 1e6, "test");
    }
    
    function test_Unpause() public {
        feeCollector.pause();
        feeCollector.unpause();
        
        // Should work now
        usdt.mint(vault, 100 * 1e6);
        vm.startPrank(vault);
        usdt.approve(address(feeCollector), 100 * 1e6);
        feeCollector.collectFees(address(usdt), 100 * 1e6, "test");
        vm.stopPrank();
    }
    
    // ============ No Insurance/Staking Contract Tests ============
    
    function test_Distribution_NoInsuranceFund() public {
        // Deploy new collector without insurance
        FeeCollector newCollector = new FeeCollector(treasury, address(0), address(0));
        newCollector.setVault(vault);
        newCollector.addSupportedToken(address(usdt));
        
        // Add fees
        usdt.mint(address(newCollector), INITIAL_BALANCE);
        
        uint256 treasuryBefore = usdt.balanceOf(treasury);
        
        newCollector.distributeToken(address(usdt));
        
        uint256 treasuryAfter = usdt.balanceOf(treasury);
        
        // All should go to treasury
        assertEq(treasuryAfter - treasuryBefore, INITIAL_BALANCE);
    }
}

// ============ Mock Contracts ============

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
