// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/core/LeveragedVault.sol";
import "../contracts/core/LendingPool.sol";
import "../contracts/core/ValueTracker.sol";
import "../contracts/periphery/PriceOracle.sol";

/**
 * @title LeveragedVaultTest
 * @notice Unit tests for LeveragedVault
 */
contract LeveragedVaultTest is Test {
    
    LeveragedVault public vault;
    LendingPool public lendingPool;
    ValueTracker public valueTracker;
    PriceOracle public priceOracle;
    
    MockERC20 public usdt;
    MockERC20 public wbtc;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public treasury = address(0x999);
    
    uint256 constant INITIAL_BALANCE = 100_000 * 1e18;
    uint256 constant BTC_PRICE = 50_000 * 1e8; // $50,000 with 8 decimals
    
    function setUp() public {
        // Deploy mock tokens
        usdt = new MockERC20("USDT", "USDT", 18);
        wbtc = new MockERC20("WBTC", "WBTC", 18);
        
        // Deploy oracle
        priceOracle = new PriceOracle();
        
        // Deploy core contracts
        lendingPool = new LendingPool(address(usdt));
        valueTracker = new ValueTracker(address(priceOracle));
        vault = new LeveragedVault(
            address(usdt),
            address(lendingPool),
            address(priceOracle),
            address(valueTracker)
        );
        
        // Configure
        lendingPool.setVault(address(vault));
        valueTracker.setVault(address(vault));
        vault.setSupportedAsset(address(wbtc), true);
        vault.setFeeCollector(treasury);
        
        // Setup mock price feed
        MockPriceFeed btcFeed = new MockPriceFeed(int256(BTC_PRICE));
        priceOracle.setPriceFeed(address(wbtc), address(btcFeed));
        
        // Mint tokens to users
        usdt.mint(user1, INITIAL_BALANCE);
        usdt.mint(user2, INITIAL_BALANCE);
        
        // Provide liquidity to lending pool
        usdt.mint(address(this), INITIAL_BALANCE * 10);
        usdt.approve(address(lendingPool), type(uint256).max);
        lendingPool.deposit(INITIAL_BALANCE * 5);
        
        // Approve vault for users
        vm.prank(user1);
        usdt.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        usdt.approve(address(vault), type(uint256).max);
    }
    
    // ============ Open Position Tests ============
    
    function test_OpenPosition_1x() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 leverage = 10000; // 1x
        
        vm.prank(user1);
        uint256 positionId = vault.openPosition(address(wbtc), depositAmount, leverage);
        
        ILeveragedVault.Position memory pos = vault.getPosition(positionId);
        
        assertEq(pos.user, user1);
        assertEq(pos.asset, address(wbtc));
        assertEq(pos.leverageMultiplier, leverage);
        assertTrue(pos.isActive);
        assertEq(pos.borrowedAmount, 0); // No borrowing for 1x
    }
    
    function test_OpenPosition_5x() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 leverage = 50000; // 5x
        
        vm.prank(user1);
        uint256 positionId = vault.openPosition(address(wbtc), depositAmount, leverage);
        
        ILeveragedVault.Position memory pos = vault.getPosition(positionId);
        
        assertEq(pos.user, user1);
        assertEq(pos.leverageMultiplier, leverage);
        assertTrue(pos.isActive);
        
        // Check borrowed amount (5x leverage means 4x borrowed)
        uint256 netDeposit = depositAmount - (depositAmount * 10 / 10000); // After 0.1% fee
        uint256 expectedBorrowed = netDeposit * 4; // 4x the deposit
        assertApproxEqRel(pos.borrowedAmount, expectedBorrowed, 0.01e18); // 1% tolerance
    }
    
    function test_OpenPosition_InvalidLeverage() public {
        uint256 depositAmount = 1000 * 1e18;
        
        vm.prank(user1);
        vm.expectRevert("Invalid leverage");
        vault.openPosition(address(wbtc), depositAmount, 60000); // 6x - too high
        
        vm.prank(user1);
        vm.expectRevert("Invalid leverage");
        vault.openPosition(address(wbtc), depositAmount, 5000); // 0.5x - too low
    }
    
    function test_OpenPosition_UnsupportedAsset() public {
        address randomToken = address(0x123);
        
        vm.prank(user1);
        vm.expectRevert("Asset not supported");
        vault.openPosition(randomToken, 1000 * 1e18, 10000);
    }
    
    // ============ Close Position Tests ============
    
    function test_ClosePosition_Profit() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 leverage = 20000; // 2x
        
        vm.prank(user1);
        uint256 positionId = vault.openPosition(address(wbtc), depositAmount, leverage);
        
        // Simulate price increase (100%)
        MockPriceFeed(priceOracle.priceFeeds(address(wbtc))).setPrice(int256(BTC_PRICE * 2));
        
        uint256 balanceBefore = usdt.balanceOf(user1);
        
        vm.prank(user1);
        vault.closePosition(positionId);
        
        uint256 balanceAfter = usdt.balanceOf(user1);
        
        // User should have more than they started with
        assertTrue(balanceAfter > balanceBefore);
        
        // Position should be closed
        ILeveragedVault.Position memory pos = vault.getPosition(positionId);
        assertFalse(pos.isActive);
    }
    
    function test_ClosePosition_Loss() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 leverage = 20000; // 2x
        
        vm.prank(user1);
        uint256 positionId = vault.openPosition(address(wbtc), depositAmount, leverage);
        
        // Simulate price decrease (20%)
        MockPriceFeed(priceOracle.priceFeeds(address(wbtc))).setPrice(int256(BTC_PRICE * 80 / 100));
        
        vm.prank(user1);
        vault.closePosition(positionId);
        
        // Position should be closed
        ILeveragedVault.Position memory pos = vault.getPosition(positionId);
        assertFalse(pos.isActive);
    }
    
    // ============ Health Factor Tests ============
    
    function test_HealthFactor_Healthy() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 leverage = 20000; // 2x
        
        vm.prank(user1);
        uint256 positionId = vault.openPosition(address(wbtc), depositAmount, leverage);
        
        uint256 healthFactor = vault.getHealthFactor(positionId);
        
        // Should be healthy (> 1.1)
        assertTrue(healthFactor > 11000);
    }
    
    function test_HealthFactor_Liquidatable() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 leverage = 50000; // 5x - high leverage
        
        vm.prank(user1);
        uint256 positionId = vault.openPosition(address(wbtc), depositAmount, leverage);
        
        // Simulate significant price drop (30%)
        MockPriceFeed(priceOracle.priceFeeds(address(wbtc))).setPrice(int256(BTC_PRICE * 70 / 100));
        
        // Should be liquidatable
        assertTrue(vault.isLiquidatable(positionId));
    }
    
    // ============ Add Collateral Tests ============
    
    function test_AddCollateral() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 leverage = 30000; // 3x
        
        vm.prank(user1);
        uint256 positionId = vault.openPosition(address(wbtc), depositAmount, leverage);
        
        uint256 healthBefore = vault.getHealthFactor(positionId);
        
        // Add collateral
        vm.prank(user1);
        vault.addCollateral(positionId, 500 * 1e18);
        
        uint256 healthAfter = vault.getHealthFactor(positionId);
        
        // Health should improve
        assertTrue(healthAfter > healthBefore);
    }
    
    // ============ Fee Tests ============
    
    function test_EntryFee() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 leverage = 10000; // 1x
        
        uint256 treasuryBefore = usdt.balanceOf(treasury);
        
        vm.prank(user1);
        vault.openPosition(address(wbtc), depositAmount, leverage);
        
        uint256 treasuryAfter = usdt.balanceOf(treasury);
        
        // Entry fee should be 0.1%
        uint256 expectedFee = depositAmount * 10 / 10000;
        assertEq(treasuryAfter - treasuryBefore, expectedFee);
    }
    
    // ============ Pause Tests ============
    
    function test_Pause() public {
        vault.pause();
        
        vm.prank(user1);
        vm.expectRevert("Paused");
        vault.openPosition(address(wbtc), 1000 * 1e18, 10000);
        
        vault.unpause();
        
        vm.prank(user1);
        vault.openPosition(address(wbtc), 1000 * 1e18, 10000); // Should work now
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

contract MockPriceFeed {
    int256 public price;
    uint8 public decimals = 8;
    
    constructor(int256 _price) {
        price = _price;
    }
    
    function setPrice(int256 _price) external {
        price = _price;
    }
    
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, price, block.timestamp, block.timestamp, 1);
    }
}
