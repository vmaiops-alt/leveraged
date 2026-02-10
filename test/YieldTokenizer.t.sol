// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/yield/PrincipalToken.sol";
import "../contracts/yield/YieldToken.sol";
import "../contracts/yield/YieldTokenizer.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockYieldToken is ERC20 {
    constructor() ERC20("Mock aUSDT", "aUSDT") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldTokenizerTest is Test {
    YieldTokenizer public tokenizer;
    MockYieldToken public underlying;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public feeRecipient = address(0x999);
    
    uint256 public maturity;
    bytes32 public marketId;
    
    function setUp() public {
        underlying = new MockYieldToken();
        tokenizer = new YieldTokenizer(feeRecipient);
        
        // Set maturity to 1 year from now
        maturity = block.timestamp + 365 days;
        
        // Create market
        marketId = tokenizer.createMarket(address(underlying), maturity);
        
        // Fund users
        underlying.mint(user1, 10_000 * 1e18);
        underlying.mint(user2, 10_000 * 1e18);
        
        // Approve tokenizer
        vm.prank(user1);
        underlying.approve(address(tokenizer), type(uint256).max);
        vm.prank(user2);
        underlying.approve(address(tokenizer), type(uint256).max);
    }
    
    // ============ Market Creation Tests ============
    
    function test_CreateMarket() public view {
        (
            address marketUnderlying,
            address pt,
            address yt,
            uint256 marketMaturity,
            uint256 totalDeposited,
            bool active
        ) = tokenizer.getMarket(marketId);
        
        assertEq(marketUnderlying, address(underlying));
        assertTrue(pt != address(0));
        assertTrue(yt != address(0));
        assertEq(marketMaturity, maturity);
        assertEq(totalDeposited, 0);
        assertTrue(active);
    }
    
    function test_CreateMarket_InvalidMaturity_TooSoon() public {
        vm.expectRevert(YieldTokenizer.InvalidMaturity.selector);
        tokenizer.createMarket(address(underlying), block.timestamp + 1 days);
    }
    
    function test_CreateMarket_InvalidMaturity_TooFar() public {
        vm.expectRevert(YieldTokenizer.InvalidMaturity.selector);
        tokenizer.createMarket(address(underlying), block.timestamp + 10 * 365 days);
    }
    
    function test_CreateMarket_Duplicate() public {
        vm.expectRevert(YieldTokenizer.MarketExists.selector);
        tokenizer.createMarket(address(underlying), maturity);
    }
    
    // ============ Deposit Tests ============
    
    function test_Deposit() public {
        uint256 depositAmount = 1000 * 1e18;
        
        vm.prank(user1);
        (uint256 ptAmount, uint256 ytAmount) = tokenizer.deposit(marketId, depositAmount);
        
        // Should receive PT and YT (minus 1% fee)
        uint256 expectedAmount = depositAmount * 99 / 100; // 1% fee
        assertEq(ptAmount, expectedAmount);
        assertEq(ytAmount, expectedAmount);
        
        // Check balances
        (,address pt, address yt,,,) = tokenizer.getMarket(marketId);
        assertEq(IERC20(pt).balanceOf(user1), expectedAmount);
        assertEq(IERC20(yt).balanceOf(user1), expectedAmount);
    }
    
    function test_Deposit_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(YieldTokenizer.ZeroAmount.selector);
        tokenizer.deposit(marketId, 0);
    }
    
    function test_Deposit_InvalidMarket() public {
        vm.prank(user1);
        vm.expectRevert(YieldTokenizer.MarketNotFound.selector);
        tokenizer.deposit(bytes32(0), 1000 * 1e18);
    }
    
    function test_Deposit_AfterMaturity() public {
        // Warp to after maturity
        vm.warp(maturity + 1);
        
        vm.prank(user1);
        vm.expectRevert(YieldTokenizer.AlreadyMatured.selector);
        tokenizer.deposit(marketId, 1000 * 1e18);
    }
    
    // ============ Redeem Tests ============
    
    function test_Redeem_BeforeMaturity() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Deposit first
        vm.prank(user1);
        (uint256 ptAmount,) = tokenizer.deposit(marketId, depositAmount);
        
        // Redeem PT + YT
        vm.prank(user1);
        uint256 redeemed = tokenizer.redeem(marketId, ptAmount);
        
        // Should get back 1:1 (minus original fee)
        assertEq(redeemed, ptAmount);
        
        // PT and YT should be burned
        (,address pt, address yt,,,) = tokenizer.getMarket(marketId);
        assertEq(IERC20(pt).balanceOf(user1), 0);
        assertEq(IERC20(yt).balanceOf(user1), 0);
    }
    
    function test_Redeem_InsufficientPT() public {
        uint256 depositAmount = 1000 * 1e18;
        
        vm.prank(user1);
        tokenizer.deposit(marketId, depositAmount);
        
        // Try to redeem more than we have
        vm.prank(user1);
        vm.expectRevert(YieldTokenizer.InsufficientBalance.selector);
        tokenizer.redeem(marketId, 2000 * 1e18);
    }
    
    // ============ Maturity Redeem Tests ============
    
    function test_RedeemAtMaturity() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // Deposit
        vm.prank(user1);
        (uint256 ptAmount,) = tokenizer.deposit(marketId, depositAmount);
        
        // Warp to maturity
        vm.warp(maturity + 1);
        
        // Redeem only PT (YT not required at maturity)
        uint256 balanceBefore = underlying.balanceOf(user1);
        vm.prank(user1);
        uint256 redeemed = tokenizer.redeemAtMaturity(marketId, ptAmount);
        uint256 balanceAfter = underlying.balanceOf(user1);
        
        assertEq(redeemed, ptAmount);
        assertEq(balanceAfter - balanceBefore, ptAmount);
    }
    
    function test_RedeemAtMaturity_BeforeMaturity() public {
        uint256 depositAmount = 1000 * 1e18;
        
        vm.prank(user1);
        (uint256 ptAmount,) = tokenizer.deposit(marketId, depositAmount);
        
        // Try to redeem before maturity
        vm.prank(user1);
        vm.expectRevert(YieldTokenizer.NotMatured.selector);
        tokenizer.redeemAtMaturity(marketId, ptAmount);
    }
    
    // ============ Fee Tests ============
    
    function test_ProtocolFee() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 expectedFee = depositAmount * 100 / 10000; // 1% fee
        
        uint256 recipientBefore = underlying.balanceOf(feeRecipient);
        
        vm.prank(user1);
        tokenizer.deposit(marketId, depositAmount);
        
        uint256 recipientAfter = underlying.balanceOf(feeRecipient);
        assertEq(recipientAfter - recipientBefore, expectedFee);
    }
    
    function test_SetProtocolFee() public {
        tokenizer.setProtocolFee(200); // 2%
        assertEq(tokenizer.protocolFee(), 200);
    }
    
    function test_SetProtocolFee_TooHigh() public {
        vm.expectRevert("Fee too high");
        tokenizer.setProtocolFee(600); // 6% - should fail
    }
    
    // ============ Admin Tests ============
    
    function test_DeactivateMarket() public {
        tokenizer.deactivateMarket(marketId);
        
        (,,,,,bool active) = tokenizer.getMarket(marketId);
        assertFalse(active);
    }
    
    function test_DeactivateMarket_CannotDeposit() public {
        tokenizer.deactivateMarket(marketId);
        
        vm.prank(user1);
        vm.expectRevert(YieldTokenizer.MarketNotFound.selector);
        tokenizer.deposit(marketId, 1000 * 1e18);
    }
    
    // ============ PT Token Tests ============
    
    function test_PT_Maturity() public {
        (,address pt,,,,) = tokenizer.getMarket(marketId);
        PrincipalToken ptToken = PrincipalToken(pt);
        
        assertEq(ptToken.maturity(), maturity);
        assertFalse(ptToken.isMatured());
        
        vm.warp(maturity + 1);
        assertTrue(ptToken.isMatured());
    }
    
    function test_PT_TimeToMaturity() public {
        (,address pt,,,,) = tokenizer.getMarket(marketId);
        PrincipalToken ptToken = PrincipalToken(pt);
        
        uint256 timeToMat = ptToken.timeToMaturity();
        assertApproxEqAbs(timeToMat, 365 days, 1);
        
        vm.warp(maturity + 1);
        assertEq(ptToken.timeToMaturity(), 0);
    }
    
    // ============ YT Token Tests ============
    
    function test_YT_Maturity() public {
        (,,address yt,,,) = tokenizer.getMarket(marketId);
        YieldToken ytToken = YieldToken(yt);
        
        assertFalse(ytToken.isMatured());
        
        vm.warp(maturity + 1);
        assertTrue(ytToken.isMatured());
    }
    
    function test_YT_TheoreticalValue() public {
        (,,address yt,,,) = tokenizer.getMarket(marketId);
        YieldToken ytToken = YieldToken(yt);
        
        // 5% APY, 1 year to maturity
        uint256 value = ytToken.getTheoreticalValue(500);
        
        // Should be approximately 5% of 1e18
        assertApproxEqAbs(value, 0.05e18, 0.001e18);
    }
    
    // ============ Integration Tests ============
    
    function test_FullFlow() public {
        uint256 depositAmount = 1000 * 1e18;
        
        // 1. Deposit
        vm.prank(user1);
        (uint256 ptAmount, uint256 ytAmount) = tokenizer.deposit(marketId, depositAmount);
        
        // 2. Transfer YT to user2 (sell yield)
        (,,address yt,,,) = tokenizer.getMarket(marketId);
        vm.prank(user1);
        IERC20(yt).transfer(user2, ytAmount);
        
        // 3. Warp to maturity
        vm.warp(maturity + 1);
        
        // 4. User1 redeems PT (gets principal)
        vm.prank(user1);
        uint256 redeemed = tokenizer.redeemAtMaturity(marketId, ptAmount);
        assertEq(redeemed, ptAmount);
        
        // 5. User2's YT is now worthless (matured)
        YieldToken ytToken = YieldToken(yt);
        assertTrue(ytToken.isMatured());
    }
    
    function test_MultipleDeposits() public {
        // User1 deposits
        vm.prank(user1);
        tokenizer.deposit(marketId, 500 * 1e18);
        
        // User2 deposits
        vm.prank(user2);
        tokenizer.deposit(marketId, 1000 * 1e18);
        
        // Check total deposited
        (,,,,uint256 totalDeposited,) = tokenizer.getMarket(marketId);
        uint256 expectedTotal = (500 + 1000) * 1e18 * 99 / 100; // minus fees
        assertEq(totalDeposited, expectedTotal);
    }
}
