// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/governance/VotingEscrow.sol";
import "../contracts/governance/GaugeController.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLVG is ERC20 {
    constructor() ERC20("LVG Token", "LVG") {
        _mint(msg.sender, 100_000_000 * 1e18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract VotingEscrowTest is Test {
    VotingEscrow public ve;
    MockLVG public lvg;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    function setUp() public {
        lvg = new MockLVG();
        ve = new VotingEscrow(address(lvg));
        
        // Fund users
        lvg.mint(user1, 10_000 * 1e18);
        lvg.mint(user2, 10_000 * 1e18);
        
        // Approvals
        vm.prank(user1);
        lvg.approve(address(ve), type(uint256).max);
        vm.prank(user2);
        lvg.approve(address(ve), type(uint256).max);
    }
    
    // ============ Lock Creation Tests ============
    
    function test_CreateLock() public {
        uint256 amount = 1000 * 1e18;
        uint256 unlockTime = block.timestamp + 365 days;
        
        vm.prank(user1);
        ve.createLock(amount, unlockTime);
        
        (uint256 lockedAmount, uint256 end, uint256 start) = ve.getLock(user1);
        
        assertEq(lockedAmount, amount);
        assertTrue(end > block.timestamp);
        assertEq(start, block.timestamp);
        assertEq(ve.totalLocked(), amount);
    }
    
    function test_CreateLock_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.ZeroAmount.selector);
        ve.createLock(0, block.timestamp + 365 days);
    }
    
    function test_CreateLock_InvalidTime_TooShort() public {
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.InvalidLockTime.selector);
        ve.createLock(1000 * 1e18, block.timestamp + 1 days);
    }
    
    function test_CreateLock_InvalidTime_TooLong() public {
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.InvalidLockTime.selector);
        ve.createLock(1000 * 1e18, block.timestamp + 5 * 365 days);
    }
    
    function test_CreateLock_AlreadyExists() public {
        uint256 unlockTime = block.timestamp + 365 days;
        
        vm.prank(user1);
        ve.createLock(1000 * 1e18, unlockTime);
        
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.LockExists.selector);
        ve.createLock(500 * 1e18, unlockTime);
    }
    
    // ============ Increase Amount Tests ============
    
    function test_IncreaseAmount() public {
        uint256 initialAmount = 1000 * 1e18;
        uint256 addAmount = 500 * 1e18;
        
        vm.prank(user1);
        ve.createLock(initialAmount, block.timestamp + 365 days);
        
        vm.prank(user1);
        ve.increaseAmount(addAmount);
        
        (uint256 lockedAmount,,) = ve.getLock(user1);
        assertEq(lockedAmount, initialAmount + addAmount);
        assertEq(ve.totalLocked(), initialAmount + addAmount);
    }
    
    function test_IncreaseAmount_NoLock() public {
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.NoLock.selector);
        ve.increaseAmount(500 * 1e18);
    }
    
    function test_IncreaseAmount_Expired() public {
        vm.prank(user1);
        ve.createLock(1000 * 1e18, block.timestamp + 30 days);
        
        // Warp past expiry
        vm.warp(block.timestamp + 31 days);
        
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.LockExpired.selector);
        ve.increaseAmount(500 * 1e18);
    }
    
    // ============ Extend Lock Tests ============
    
    function test_ExtendLock() public {
        uint256 originalEnd = block.timestamp + 180 days;
        uint256 newEnd = block.timestamp + 365 days;
        
        vm.prank(user1);
        ve.createLock(1000 * 1e18, originalEnd);
        
        vm.prank(user1);
        ve.extendLock(newEnd);
        
        (, uint256 end,) = ve.getLock(user1);
        // Should be rounded to week
        assertTrue(end >= newEnd - 7 days);
    }
    
    function test_ExtendLock_ShorterTime() public {
        vm.prank(user1);
        ve.createLock(1000 * 1e18, block.timestamp + 365 days);
        
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.InvalidLockTime.selector);
        ve.extendLock(block.timestamp + 180 days);
    }
    
    // ============ Withdraw Tests ============
    
    function test_Withdraw() public {
        uint256 amount = 1000 * 1e18;
        
        vm.prank(user1);
        ve.createLock(amount, block.timestamp + 30 days);
        
        uint256 balanceBefore = lvg.balanceOf(user1);
        
        // Warp past expiry
        vm.warp(block.timestamp + 31 days);
        
        vm.prank(user1);
        ve.withdraw();
        
        uint256 balanceAfter = lvg.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, amount);
        
        (uint256 lockedAmount,,) = ve.getLock(user1);
        assertEq(lockedAmount, 0);
    }
    
    function test_Withdraw_NotExpired() public {
        vm.prank(user1);
        ve.createLock(1000 * 1e18, block.timestamp + 365 days);
        
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.LockNotExpired.selector);
        ve.withdraw();
    }
    
    function test_Withdraw_NoLock() public {
        vm.prank(user1);
        vm.expectRevert(VotingEscrow.NoLock.selector);
        ve.withdraw();
    }
    
    // ============ Voting Power Tests ============
    
    function test_VotingPower_MaxLock() public {
        uint256 amount = 1000 * 1e18;
        uint256 maxLock = 4 * 365 days;
        
        vm.prank(user1);
        ve.createLock(amount, block.timestamp + maxLock);
        
        uint256 power = ve.balanceOf(user1);
        
        // With max lock, power should be close to amount
        // (slightly less due to week rounding)
        assertGt(power, amount * 90 / 100);
    }
    
    function test_VotingPower_HalfLock() public {
        uint256 amount = 1000 * 1e18;
        uint256 halfLock = 2 * 365 days;
        
        vm.prank(user1);
        ve.createLock(amount, block.timestamp + halfLock);
        
        uint256 power = ve.balanceOf(user1);
        
        // With half lock, power should be ~50% of amount
        assertApproxEqRel(power, amount / 2, 0.1e18); // 10% tolerance
    }
    
    function test_VotingPower_Decays() public {
        uint256 amount = 1000 * 1e18;
        
        vm.prank(user1);
        ve.createLock(amount, block.timestamp + 365 days);
        
        uint256 powerBefore = ve.balanceOf(user1);
        
        // Warp 6 months
        vm.warp(block.timestamp + 180 days);
        
        uint256 powerAfter = ve.balanceOf(user1);
        
        // Power should have decayed
        assertLt(powerAfter, powerBefore);
    }
    
    function test_VotingPower_AfterExpiry() public {
        vm.prank(user1);
        ve.createLock(1000 * 1e18, block.timestamp + 30 days);
        
        vm.warp(block.timestamp + 31 days);
        
        uint256 power = ve.balanceOf(user1);
        assertEq(power, 0);
    }
    
    // ============ Time To Unlock Tests ============
    
    function test_TimeToUnlock() public {
        uint256 lockDuration = 365 days;
        
        vm.prank(user1);
        ve.createLock(1000 * 1e18, block.timestamp + lockDuration);
        
        uint256 timeLeft = ve.timeToUnlock(user1);
        assertApproxEqAbs(timeLeft, lockDuration, 7 days); // Week rounding tolerance
    }
    
    function test_TimeToUnlock_Expired() public {
        vm.prank(user1);
        ve.createLock(1000 * 1e18, block.timestamp + 30 days);
        
        vm.warp(block.timestamp + 31 days);
        
        uint256 timeLeft = ve.timeToUnlock(user1);
        assertEq(timeLeft, 0);
    }
}

contract GaugeControllerTest is Test {
    GaugeController public gaugeController;
    VotingEscrow public ve;
    MockLVG public lvg;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public pool1 = address(0x111);
    address public pool2 = address(0x222);
    
    function setUp() public {
        lvg = new MockLVG();
        ve = new VotingEscrow(address(lvg));
        gaugeController = new GaugeController(address(ve));
        
        // Fund and lock for users
        lvg.mint(user1, 10_000 * 1e18);
        lvg.mint(user2, 10_000 * 1e18);
        
        vm.prank(user1);
        lvg.approve(address(ve), type(uint256).max);
        vm.prank(user2);
        lvg.approve(address(ve), type(uint256).max);
        
        // Create locks to get voting power
        vm.prank(user1);
        ve.createLock(5000 * 1e18, block.timestamp + 4 * 365 days);
        vm.prank(user2);
        ve.createLock(5000 * 1e18, block.timestamp + 4 * 365 days);
        
        // Add gauges
        gaugeController.addGauge(pool1, "USDT Pool");
        gaugeController.addGauge(pool2, "BTC Pool");
    }
    
    // ============ Gauge Management Tests ============
    
    function test_AddGauge() public view {
        (address pool, , bool active, string memory name) = gaugeController.gauges(0);
        
        assertEq(pool, pool1);
        assertTrue(active);
        assertEq(name, "USDT Pool");
    }
    
    function test_RemoveGauge() public {
        gaugeController.removeGauge(0);
        
        (, , bool active,) = gaugeController.gauges(0);
        assertFalse(active);
    }
    
    function test_GetGauges() public view {
        GaugeController.Gauge[] memory allGauges = gaugeController.getGauges();
        assertEq(allGauges.length, 2);
    }
    
    // ============ Voting Tests ============
    
    function test_Vote() public {
        vm.prank(user1);
        gaugeController.vote(0, 5000); // 50% of vote power to gauge 0
        
        uint256 gaugeVotes = gaugeController.gaugeVotes(0);
        assertTrue(gaugeVotes > 0);
    }
    
    function test_Vote_MultipleGauges() public {
        vm.prank(user1);
        gaugeController.vote(0, 6000); // 60% to gauge 0
        
        vm.prank(user1);
        gaugeController.vote(1, 4000); // 40% to gauge 1
        
        uint256 used = gaugeController.userVotePowerUsed(user1);
        assertEq(used, 10000); // 100% used
    }
    
    function test_Vote_ExceedsMaxWeight() public {
        vm.prank(user1);
        gaugeController.vote(0, 7000); // 70%
        
        vm.prank(user1);
        vm.expectRevert(GaugeController.ExceedsMaxWeight.selector);
        gaugeController.vote(1, 5000); // Would be 120% total
    }
    
    function test_Vote_NoVotingPower() public {
        address noLock = address(0x999);
        
        vm.prank(noLock);
        vm.expectRevert(GaugeController.NoVotingPower.selector);
        gaugeController.vote(0, 5000);
    }
    
    function test_Vote_InvalidGauge() public {
        vm.prank(user1);
        vm.expectRevert(GaugeController.GaugeNotFound.selector);
        gaugeController.vote(99, 5000);
    }
    
    function test_Vote_InactiveGauge() public {
        gaugeController.removeGauge(0);
        
        vm.prank(user1);
        vm.expectRevert(GaugeController.GaugeNotActive.selector);
        gaugeController.vote(0, 5000);
    }
    
    function test_Vote_InvalidWeight() public {
        vm.prank(user1);
        vm.expectRevert(GaugeController.InvalidWeight.selector);
        gaugeController.vote(0, 15000); // 150% - invalid
    }
    
    // ============ Vote Reset Tests ============
    
    function test_ResetVote() public {
        vm.prank(user1);
        gaugeController.vote(0, 5000);
        
        uint256 votesBefore = gaugeController.gaugeVotes(0);
        
        vm.prank(user1);
        gaugeController.resetVote(0);
        
        uint256 votesAfter = gaugeController.gaugeVotes(0);
        assertLt(votesAfter, votesBefore);
        
        uint256 used = gaugeController.userVotePowerUsed(user1);
        assertEq(used, 0);
    }
    
    // ============ Relative Weight Tests ============
    
    function test_GetGaugeRelativeWeight() public {
        vm.prank(user1);
        gaugeController.vote(0, 7500); // 75%
        
        vm.prank(user1);
        gaugeController.vote(1, 2500); // 25%
        
        uint256 weight0 = gaugeController.getGaugeRelativeWeight(0);
        uint256 weight1 = gaugeController.getGaugeRelativeWeight(1);
        
        // Should be 75% and 25%
        assertApproxEqAbs(weight0, 7500, 100);
        assertApproxEqAbs(weight1, 2500, 100);
    }
    
    function test_GetGaugeRelativeWeight_NoVotes() public view {
        uint256 weight = gaugeController.getGaugeRelativeWeight(0);
        assertEq(weight, 0);
    }
    
    // ============ Remaining Vote Power Tests ============
    
    function test_GetRemainingVotePower() public {
        assertEq(gaugeController.getRemainingVotePower(user1), 10000);
        
        vm.prank(user1);
        gaugeController.vote(0, 6000);
        
        assertEq(gaugeController.getRemainingVotePower(user1), 4000);
    }
    
    // ============ Vote Cooldown Tests ============
    
    function test_Vote_Cooldown() public {
        vm.prank(user1);
        gaugeController.vote(0, 5000);
        
        // Try to change vote immediately
        vm.prank(user1);
        vm.expectRevert(GaugeController.VoteTooSoon.selector);
        gaugeController.vote(0, 3000);
        
        // Warp past cooldown
        vm.warp(block.timestamp + 11 days);
        
        // Now should work
        vm.prank(user1);
        gaugeController.vote(0, 3000);
    }
}
