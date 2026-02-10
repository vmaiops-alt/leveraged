// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/core/LendingPoolV5.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 1_000_000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock Flash Loan Receiver
contract MockFlashReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address,
        bytes calldata
    ) external returns (bool) {
        // Repay loan + fee
        IERC20(asset).transfer(msg.sender, amount + fee);
        return true;
    }
}

// Malicious Flash Loan Receiver (doesn't repay)
contract MaliciousFlashReceiver {
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata
    ) external returns (bool) {
        // Don't repay - should fail
        return true;
    }
}

contract LendingPoolV5Test is Test {
    LendingPoolV5 public pool;
    MockToken public token;
    MockFlashReceiver public flashReceiver;
    MaliciousFlashReceiver public maliciousReceiver;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public vault = address(0x3);
    
    function setUp() public {
        // Deploy mock token
        token = new MockToken();
        
        // Deploy pool
        pool = new LendingPoolV5(address(token));
        pool.setVault(vault);
        
        // Deploy flash receivers
        flashReceiver = new MockFlashReceiver();
        maliciousReceiver = new MaliciousFlashReceiver();
        
        // Fund test accounts
        token.mint(alice, 100_000 * 10**18);
        token.mint(bob, 100_000 * 10**18);
        token.mint(address(flashReceiver), 10_000 * 10**18); // For repaying fees
        
        // Approve pool
        vm.prank(alice);
        token.approve(address(pool), type(uint256).max);
        
        vm.prank(bob);
        token.approve(address(pool), type(uint256).max);
    }
    
    // ============ Deposit Tests ============
    
    function test_Deposit() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**18);
        
        assertEq(pool.totalDeposits(), 1000 * 10**18);
        assertEq(pool.totalShares(), 1000 * 10**18);
        assertEq(pool.balanceOf(alice), 1000 * 10**18);
    }
    
    function test_DepositMultipleUsers() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**18);
        
        vm.prank(bob);
        pool.deposit(500 * 10**18);
        
        assertEq(pool.totalDeposits(), 1500 * 10**18);
        assertEq(pool.balanceOf(alice), 1000 * 10**18);
        assertEq(pool.balanceOf(bob), 500 * 10**18);
    }
    
    function test_RevertZeroDeposit() public {
        vm.prank(alice);
        vm.expectRevert("Zero amount");
        pool.deposit(0);
    }
    
    // ============ Withdraw Tests ============
    
    function test_Withdraw() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**18);
        
        uint256 balanceBefore = token.balanceOf(alice);
        
        vm.prank(alice);
        pool.withdraw(500 * 10**18);
        
        assertEq(pool.balanceOf(alice), 500 * 10**18);
        assertEq(token.balanceOf(alice), balanceBefore + 500 * 10**18);
    }
    
    function test_WithdrawAll() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**18);
        
        vm.prank(alice);
        pool.withdraw(1000 * 10**18);
        
        assertEq(pool.balanceOf(alice), 0);
        assertEq(pool.totalDeposits(), 0);
    }
    
    function test_RevertWithdrawInsufficientShares() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**18);
        
        vm.prank(alice);
        vm.expectRevert("Insufficient shares");
        pool.withdraw(2000 * 10**18);
    }
    
    // ============ E-Mode Tests ============
    
    function test_DefaultEMode() public {
        assertEq(pool.getUserEMode(alice), 0);
        assertEq(pool.getUserLTV(alice), 8000); // 80%
    }
    
    function test_SetEModeStablecoins() public {
        vm.prank(alice);
        pool.setUserEMode(1); // Stablecoins
        
        assertEq(pool.getUserEMode(alice), 1);
        assertEq(pool.getUserLTV(alice), 9700); // 97%
    }
    
    function test_SetEModeETHCorrelated() public {
        vm.prank(alice);
        pool.setUserEMode(2); // ETH Correlated
        
        assertEq(pool.getUserEMode(alice), 2);
        assertEq(pool.getUserLTV(alice), 9300); // 93%
    }
    
    function test_SetEModeBTCCorrelated() public {
        vm.prank(alice);
        pool.setUserEMode(3); // BTC Correlated
        
        assertEq(pool.getUserEMode(alice), 3);
        assertEq(pool.getUserLTV(alice), 9300); // 93%
    }
    
    function test_DisableEMode() public {
        vm.startPrank(alice);
        pool.setUserEMode(1);
        pool.setUserEMode(0); // Disable
        vm.stopPrank();
        
        assertEq(pool.getUserEMode(alice), 0);
        assertEq(pool.getUserLTV(alice), 8000);
    }
    
    function test_RevertInvalidEModeCategory() public {
        vm.prank(alice);
        vm.expectRevert("Invalid category");
        pool.setUserEMode(99);
    }
    
    function test_GetEModeCategory() public {
        (uint16 ltv, uint16 threshold, uint16 bonus, string memory label) = pool.getEModeCategory(1);
        
        assertEq(ltv, 9700);
        assertEq(threshold, 9750);
        assertEq(bonus, 100);
        assertEq(label, "Stablecoins");
    }
    
    // ============ Flash Loan Tests ============
    
    function test_FlashLoan() public {
        // First deposit some liquidity
        vm.prank(alice);
        pool.deposit(10000 * 10**18);
        
        uint256 loanAmount = 1000 * 10**18;
        uint256 expectedFee = (loanAmount * 5) / 10000; // 0.05%
        
        uint256 poolBalanceBefore = pool.totalDeposits();
        
        pool.flashLoan(
            address(flashReceiver),
            loanAmount,
            ""
        );
        
        // Pool should have gained the fee
        assertEq(pool.totalDeposits(), poolBalanceBefore + expectedFee);
    }
    
    function test_RevertFlashLoanNotRepaid() public {
        vm.prank(alice);
        pool.deposit(10000 * 10**18);
        
        vm.expectRevert("Flash loan not repaid");
        pool.flashLoan(
            address(maliciousReceiver),
            1000 * 10**18,
            ""
        );
    }
    
    function test_RevertFlashLoanInsufficientLiquidity() public {
        vm.prank(alice);
        pool.deposit(100 * 10**18);
        
        vm.expectRevert("Insufficient liquidity");
        pool.flashLoan(
            address(flashReceiver),
            1000 * 10**18, // More than available
            ""
        );
    }
    
    function test_RevertFlashLoanZeroAmount() public {
        vm.prank(alice);
        pool.deposit(10000 * 10**18);
        
        vm.expectRevert("Zero amount");
        pool.flashLoan(address(flashReceiver), 0, "");
    }
    
    // ============ Interest Rate Tests ============
    
    function test_BorrowRateAtZeroUtilization() public {
        vm.prank(alice);
        pool.deposit(10000 * 10**18);
        
        uint256 borrowRate = pool.getBorrowRate();
        assertEq(borrowRate, 500); // BASE_RATE = 5%
    }
    
    function test_BorrowRateAtOptimalUtilization() public {
        vm.prank(alice);
        pool.deposit(10000 * 10**18);
        
        // Simulate 80% utilization
        vm.prank(vault);
        pool.borrow(8000 * 10**18);
        
        uint256 borrowRate = pool.getBorrowRate();
        // At optimal (80%), rate = BASE_RATE + SLOPE1 = 500 + 2700 = 3200 (32%)
        assertEq(borrowRate, 3200);
    }
    
    function test_SupplyRateScalesWithUtilization() public {
        vm.prank(alice);
        pool.deposit(10000 * 10**18);
        
        uint256 supplyRateZero = pool.getSupplyRate();
        assertEq(supplyRateZero, 0); // No borrows = 0% supply rate
        
        vm.prank(vault);
        pool.borrow(5000 * 10**18); // 50% utilization
        
        uint256 supplyRateFifty = pool.getSupplyRate();
        assertGt(supplyRateFifty, 0);
    }
    
    // ============ Admin Tests ============
    
    function test_AddEModeCategory() public {
        uint8 newId = pool.addEModeCategory(
            9500,  // 95% LTV
            9600,  // 96% threshold
            200,   // 2% bonus
            address(0),
            "Custom Category"
        );
        
        assertEq(newId, 4); // Should be category 4
        
        (uint16 ltv, , , string memory label) = pool.getEModeCategory(4);
        assertEq(ltv, 9500);
        assertEq(label, "Custom Category");
    }
    
    function test_RevertNonOwnerAddCategory() public {
        vm.prank(alice);
        vm.expectRevert("Not owner");
        pool.addEModeCategory(9500, 9600, 200, address(0), "Test");
    }
    
    function test_UpdateEModeCategory() public {
        pool.updateEModeCategory(1, 9600, 9700, 150);
        
        (uint16 ltv, uint16 threshold, uint16 bonus,) = pool.getEModeCategory(1);
        assertEq(ltv, 9600);
        assertEq(threshold, 9700);
        assertEq(bonus, 150);
    }
    
    // ============ Health Factor Tests ============
    
    function test_HealthFactorNoBorrow() public {
        vm.prank(alice);
        pool.deposit(1000 * 10**18);
        
        uint256 healthFactor = pool.getHealthFactor(alice);
        assertEq(healthFactor, type(uint256).max);
    }
}
