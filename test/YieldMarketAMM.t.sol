// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/yield/YieldMarketAMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldMarketAMMTest is Test {
    YieldMarketAMM public amm;
    MockToken public pt;
    MockToken public underlying;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public feeRecipient = address(0x999);
    
    uint256 public maturity;
    uint256 public constant INITIAL_RATE = 0.05e18; // 5% APY
    
    function setUp() public {
        pt = new MockToken("PT-aUSDT", "PT-aUSDT");
        underlying = new MockToken("USDT", "USDT");
        
        maturity = block.timestamp + 365 days;
        
        amm = new YieldMarketAMM(
            address(pt),
            address(underlying),
            maturity,
            INITIAL_RATE,
            feeRecipient
        );
        
        // Fund users
        pt.mint(user1, 100_000 * 1e18);
        underlying.mint(user1, 100_000 * 1e18);
        pt.mint(user2, 100_000 * 1e18);
        underlying.mint(user2, 100_000 * 1e18);
        
        // Approvals
        vm.prank(user1);
        pt.approve(address(amm), type(uint256).max);
        vm.prank(user1);
        underlying.approve(address(amm), type(uint256).max);
        vm.prank(user2);
        pt.approve(address(amm), type(uint256).max);
        vm.prank(user2);
        underlying.approve(address(amm), type(uint256).max);
    }
    
    // ============ Liquidity Tests ============
    
    function test_AddInitialLiquidity() public {
        uint256 ptAmount = 10_000 * 1e18;
        uint256 underlyingAmount = 9_500 * 1e18; // PT at 5% discount
        
        vm.prank(user1);
        (uint256 lpTokens, uint256 ptActual, uint256 underlyingActual) = amm.addLiquidity(
            ptAmount,
            underlyingAmount,
            0
        );
        
        assertTrue(lpTokens > 0);
        assertEq(ptActual, ptAmount);
        assertEq(underlyingActual, underlyingAmount);
        assertEq(amm.balanceOf(user1), lpTokens);
        assertEq(amm.ptReserve(), ptAmount);
        assertEq(amm.underlyingReserve(), underlyingAmount);
    }
    
    function test_AddLiquidity_Proportional() public {
        // Add initial liquidity
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        // Add more liquidity
        vm.prank(user2);
        (uint256 lpTokens, uint256 ptActual, uint256 underlyingActual) = amm.addLiquidity(
            5_000 * 1e18,
            5_000 * 1e18,
            0
        );
        
        assertTrue(lpTokens > 0);
        // Should be proportional to initial ratio
        assertApproxEqRel(ptActual * 9500, underlyingActual * 10000, 0.01e18);
    }
    
    function test_AddLiquidity_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(YieldMarketAMM.ZeroAmount.selector);
        amm.addLiquidity(0, 1000 * 1e18, 0);
    }
    
    function test_RemoveLiquidity() public {
        // Add liquidity
        vm.prank(user1);
        (uint256 lpTokens,,) = amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 ptBefore = pt.balanceOf(user1);
        uint256 underlyingBefore = underlying.balanceOf(user1);
        
        // Remove half
        vm.prank(user1);
        (uint256 ptOut, uint256 underlyingOut) = amm.removeLiquidity(lpTokens / 2, 0, 0);
        
        assertEq(pt.balanceOf(user1), ptBefore + ptOut);
        assertEq(underlying.balanceOf(user1), underlyingBefore + underlyingOut);
        assertEq(amm.balanceOf(user1), lpTokens / 2);
    }
    
    function test_RemoveLiquidity_All() public {
        vm.prank(user1);
        (uint256 lpTokens,,) = amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        vm.prank(user1);
        amm.removeLiquidity(lpTokens, 0, 0);
        
        assertEq(amm.balanceOf(user1), 0);
        assertEq(amm.ptReserve(), 0);
        assertEq(amm.underlyingReserve(), 0);
    }
    
    // ============ Swap Tests ============
    
    function test_SwapPtForUnderlying() public {
        // Add liquidity first
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 ptIn = 100 * 1e18;
        uint256 underlyingBefore = underlying.balanceOf(user2);
        
        vm.prank(user2);
        uint256 underlyingOut = amm.swapPtForUnderlying(ptIn, 0);
        
        assertTrue(underlyingOut > 0);
        assertEq(underlying.balanceOf(user2), underlyingBefore + underlyingOut);
    }
    
    function test_SwapUnderlyingForPt() public {
        // Add liquidity first
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 underlyingIn = 100 * 1e18;
        uint256 ptBefore = pt.balanceOf(user2);
        
        vm.prank(user2);
        uint256 ptOut = amm.swapUnderlyingForPt(underlyingIn, 0);
        
        assertTrue(ptOut > 0);
        assertEq(pt.balanceOf(user2), ptBefore + ptOut);
    }
    
    function test_Swap_ZeroAmount() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        vm.prank(user2);
        vm.expectRevert(YieldMarketAMM.ZeroAmount.selector);
        amm.swapPtForUnderlying(0, 0);
    }
    
    function test_Swap_SlippageProtection() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        vm.prank(user2);
        vm.expectRevert(YieldMarketAMM.InsufficientOutput.selector);
        amm.swapPtForUnderlying(100 * 1e18, 1000 * 1e18); // Unrealistic min
    }
    
    function test_Swap_LargeSwapAffectsPrice() public {
        // With constant product AMM, large swaps have high slippage
        // but don't fail - they just get less output
        vm.prank(user1);
        amm.addLiquidity(100 * 1e18, 95 * 1e18, 0);
        
        // Large swap relative to pool - should work but with bad rate
        vm.prank(user2);
        uint256 out = amm.swapPtForUnderlying(50 * 1e18, 0);
        
        // Output should be much less than 50 due to slippage
        assertTrue(out < 45 * 1e18);
    }
    
    // ============ Quote Tests ============
    
    function test_QuotePtForUnderlying() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 quote = amm.quotePtForUnderlying(100 * 1e18);
        assertTrue(quote > 0);
        assertTrue(quote < 100 * 1e18); // Should be less due to discount + fee
    }
    
    function test_QuoteUnderlyingForPt() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 quote = amm.quoteUnderlyingForPt(100 * 1e18);
        assertTrue(quote > 0);
        assertTrue(quote > 100 * 1e18); // Should be more due to discount
    }
    
    // ============ Price Tests ============
    
    function test_GetPtPrice() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 price = amm.getPtPrice();
        // PT at 5% discount means price = 0.95
        assertApproxEqRel(price, 0.95e18, 0.01e18);
    }
    
    function test_GetImpliedRate() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 rate = amm.getImpliedRate();
        // Should be around 5% (0.05e18)
        assertTrue(rate > 0);
    }
    
    // ============ Time Decay Tests ============
    
    function test_PriceConvergesAtMaturity() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 priceBefore = amm.getPtPrice();
        
        // Warp to near maturity
        vm.warp(maturity - 1 days);
        
        uint256 priceAfter = amm.getPtPrice();
        
        // Price should be closer to 1.0 at maturity
        // (reserve ratio doesn't change, but discount factor does)
        assertTrue(priceAfter >= priceBefore || priceAfter == priceBefore);
    }
    
    function test_TimeToMaturity() public view {
        uint256 time = amm.timeToMaturity();
        assertApproxEqAbs(time, 365 days, 1);
    }
    
    function test_TimeToMaturity_Expired() public {
        vm.warp(maturity + 1);
        assertEq(amm.timeToMaturity(), 0);
    }
    
    // ============ Expired Tests ============
    
    function test_Swap_Expired() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        vm.warp(maturity + 1);
        
        vm.prank(user2);
        vm.expectRevert(YieldMarketAMM.Expired.selector);
        amm.swapPtForUnderlying(100 * 1e18, 0);
    }
    
    function test_AddLiquidity_Expired() public {
        vm.warp(maturity + 1);
        
        vm.prank(user1);
        vm.expectRevert(YieldMarketAMM.Expired.selector);
        amm.addLiquidity(100 * 1e18, 95 * 1e18, 0);
    }
    
    function test_RemoveLiquidity_AfterExpiry() public {
        // Can still remove liquidity after expiry
        vm.prank(user1);
        (uint256 lpTokens,,) = amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        vm.warp(maturity + 1);
        
        vm.prank(user1);
        amm.removeLiquidity(lpTokens, 0, 0); // Should work
    }
    
    // ============ Fee Tests ============
    
    function test_SwapFee() public {
        vm.prank(user1);
        amm.addLiquidity(10_000 * 1e18, 9_500 * 1e18, 0);
        
        uint256 feeBefore = underlying.balanceOf(feeRecipient);
        
        vm.prank(user2);
        amm.swapPtForUnderlying(100 * 1e18, 0);
        
        uint256 feeAfter = underlying.balanceOf(feeRecipient);
        assertTrue(feeAfter > feeBefore);
    }
    
    function test_SetSwapFee() public {
        amm.setSwapFee(50); // 0.5%
        assertEq(amm.swapFee(), 50);
    }
    
    function test_SetSwapFee_TooHigh() public {
        vm.expectRevert("Fee too high");
        amm.setSwapFee(150); // 1.5%
    }
    
    // ============ Admin Tests ============
    
    function test_SetScalar() public {
        amm.setScalar(200);
        assertEq(amm.scalar(), 200);
    }
    
    function test_SetFeeRecipient() public {
        address newRecipient = address(0x888);
        amm.setFeeRecipient(newRecipient);
        assertEq(amm.feeRecipient(), newRecipient);
    }
}
