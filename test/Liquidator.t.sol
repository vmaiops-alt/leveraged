// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/periphery/Liquidator.sol";
import "../contracts/core/LeveragedVault.sol";
import "../contracts/core/LendingPool.sol";
import "../contracts/core/ValueTracker.sol";
import "../contracts/periphery/PriceOracle.sol";

/**
 * @title LiquidatorTest
 * @notice Unit tests for Liquidator contract
 */
contract LiquidatorTest is Test {
    
    Liquidator public liquidator;
    LeveragedVault public vault;
    LendingPool public lendingPool;
    ValueTracker public valueTracker;
    PriceOracle public priceOracle;
    
    MockERC20 public usdt;
    MockERC20 public wbtc;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public keeper1 = address(0x100);
    address public keeper2 = address(0x200);
    address public treasury = address(0x999);
    
    uint256 constant INITIAL_BALANCE = 100_000 * 1e18;
    uint256 constant BTC_PRICE = 50_000 * 1e8;
    
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
        
        // Deploy liquidator
        liquidator = new Liquidator(address(vault));
        
        // Configure
        lendingPool.setVault(address(vault));
        valueTracker.setVault(address(vault));
        vault.setSupportedAsset(address(wbtc), true);
        vault.setFeeCollector(treasury);
        
        // Setup mock price feed
        MockPriceFeed btcFeed = new MockPriceFeed(int256(BTC_PRICE));
        priceOracle.setPriceFeed(address(wbtc), address(btcFeed));
        
        // Mint tokens
        usdt.mint(user1, INITIAL_BALANCE);
        usdt.mint(keeper1, INITIAL_BALANCE);
        
        // Provide liquidity
        usdt.mint(address(this), INITIAL_BALANCE * 10);
        usdt.approve(address(lendingPool), type(uint256).max);
        lendingPool.deposit(INITIAL_BALANCE * 5);
        
        // Approve vault
        vm.prank(user1);
        usdt.approve(address(vault), type(uint256).max);
    }
    
    // ============ Keeper Management Tests ============
    
    function test_AddKeeper() public {
        liquidator.addKeeper(keeper1);
        
        assertTrue(liquidator.isKeeper(keeper1));
        assertEq(liquidator.getKeeperCount(), 1);
    }
    
    function test_AddKeeper_Duplicate() public {
        liquidator.addKeeper(keeper1);
        
        vm.expectRevert("Already keeper");
        liquidator.addKeeper(keeper1);
    }
    
    function test_RemoveKeeper() public {
        liquidator.addKeeper(keeper1);
        liquidator.addKeeper(keeper2);
        
        assertEq(liquidator.getKeeperCount(), 2);
        
        liquidator.removeKeeper(keeper1);
        
        assertFalse(liquidator.isKeeper(keeper1));
        assertTrue(liquidator.isKeeper(keeper2));
        assertEq(liquidator.getKeeperCount(), 1);
    }
    
    function test_RemoveKeeper_NotKeeper() public {
        vm.expectRevert("Not keeper");
        liquidator.removeKeeper(keeper1);
    }
    
    // ============ Keeper Only Mode Tests ============
    
    function test_KeeperOnlyMode() public {
        liquidator.addKeeper(keeper1);
        liquidator.setKeeperOnlyMode(true);
        
        // Create liquidatable position
        _createLiquidatablePosition();
        
        // Non-keeper should fail
        vm.prank(user1);
        vm.expectRevert("Not authorized keeper");
        liquidator.liquidate(0);
        
        // Keeper should succeed
        vm.prank(keeper1);
        liquidator.liquidate(0);
    }
    
    function test_PublicLiquidation() public {
        // Keeper only mode OFF by default
        assertFalse(liquidator.isKeeperOnlyMode());
        
        // Create liquidatable position
        _createLiquidatablePosition();
        
        // Anyone can liquidate
        vm.prank(user1);
        liquidator.liquidate(0);
    }
    
    // ============ Single Liquidation Tests ============
    
    function test_Liquidate_Success() public {
        _createLiquidatablePosition();
        
        (uint256 debtRepaid, uint256 collateralSeized) = liquidator.liquidate(0);
        
        assertTrue(debtRepaid > 0);
        assertTrue(collateralSeized > 0);
        
        // Position should be closed
        ILeveragedVault.Position memory pos = vault.getPosition(0);
        assertFalse(pos.isActive);
    }
    
    function test_Liquidate_NotLiquidatable() public {
        // Create healthy position (1x leverage)
        vm.prank(user1);
        vault.openPosition(address(wbtc), 1000 * 1e18, 10000);
        
        vm.expectRevert("Position not liquidatable");
        liquidator.liquidate(0);
    }
    
    function test_Liquidate_Paused() public {
        _createLiquidatablePosition();
        
        liquidator.pause();
        
        vm.expectRevert("Paused");
        liquidator.liquidate(0);
    }
    
    // ============ Batch Liquidation Tests ============
    
    function test_BatchLiquidate() public {
        // Create multiple liquidatable positions
        _createLiquidatablePosition();
        
        usdt.mint(address(0x2), INITIAL_BALANCE);
        vm.startPrank(address(0x2));
        usdt.approve(address(vault), type(uint256).max);
        vault.openPosition(address(wbtc), 1000 * 1e18, 50000);
        vm.stopPrank();
        
        // Drop price to make both liquidatable
        MockPriceFeed(priceOracle.priceFeeds(address(wbtc))).setPrice(int256(BTC_PRICE * 60 / 100));
        
        uint256[] memory positions = new uint256[](2);
        positions[0] = 0;
        positions[1] = 1;
        
        (uint256 totalDebt, uint256 totalCollateral) = liquidator.batchLiquidate(positions);
        
        assertTrue(totalDebt > 0);
        assertTrue(totalCollateral > 0);
    }
    
    function test_BatchLiquidate_EmptyArray() public {
        uint256[] memory positions = new uint256[](0);
        
        vm.expectRevert("Empty array");
        liquidator.batchLiquidate(positions);
    }
    
    function test_BatchLiquidate_ExceedsMax() public {
        uint256[] memory positions = new uint256[](51);
        
        vm.expectRevert("Exceeds max batch size");
        liquidator.batchLiquidate(positions);
    }
    
    // ============ Reward Estimation Tests ============
    
    function test_EstimateLiquidationReward() public {
        _createLiquidatablePosition();
        
        uint256 reward = liquidator.estimateLiquidationReward(0);
        
        // Should be approximately 5% of exposure
        assertTrue(reward > 0);
    }
    
    function test_EstimateLiquidationReward_NotLiquidatable() public {
        // Healthy position
        vm.prank(user1);
        vault.openPosition(address(wbtc), 1000 * 1e18, 10000);
        
        uint256 reward = liquidator.estimateLiquidationReward(0);
        assertEq(reward, 0);
    }
    
    // ============ View Functions Tests ============
    
    function test_GetAllKeepers() public {
        liquidator.addKeeper(keeper1);
        liquidator.addKeeper(keeper2);
        
        address[] memory keepers = liquidator.getAllKeepers();
        
        assertEq(keepers.length, 2);
        assertEq(keepers[0], keeper1);
        assertEq(keepers[1], keeper2);
    }
    
    // ============ Admin Tests ============
    
    function test_TransferOwnership() public {
        liquidator.transferOwnership(keeper1);
        
        vm.prank(keeper1);
        liquidator.addKeeper(keeper2); // Should work as new owner
    }
    
    function test_SetVault() public {
        address newVault = address(0x456);
        liquidator.setVault(newVault);
        
        assertEq(address(liquidator.vault()), newVault);
    }
    
    // ============ Helpers ============
    
    function _createLiquidatablePosition() internal {
        // Create high leverage position
        vm.prank(user1);
        vault.openPosition(address(wbtc), 1000 * 1e18, 50000); // 5x
        
        // Drop price significantly
        MockPriceFeed(priceOracle.priceFeeds(address(wbtc))).setPrice(int256(BTC_PRICE * 70 / 100));
        
        // Verify it's liquidatable
        assertTrue(vault.isLiquidatable(0));
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
