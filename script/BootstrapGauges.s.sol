// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

interface IGaugeController {
    function addGauge(address pool, string calldata name) external returns (uint256 gaugeId);
    function removeGauge(uint256 gaugeId) external;
    function gauges(uint256 id) external view returns (
        address pool,
        uint256 weight,
        bool active,
        string memory name
    );
    function gaugeCount() external view returns (uint256);
    function getGauges() external view returns (Gauge[] memory);
    function gaugeVotes(uint256 gaugeId) external view returns (uint256);
    function totalVotes() external view returns (uint256);
    function getGaugeRelativeWeight(uint256 gaugeId) external view returns (uint256);
    
    struct Gauge {
        address pool;
        uint256 weight;
        bool active;
        string name;
    }
}

/**
 * @title BootstrapGauges
 * @notice Sets up gauge weights for LVG emission distribution
 * @dev Run with: forge script script/BootstrapGauges.s.sol --rpc-url bsc --broadcast
 * 
 * This script:
 * 1. Adds USDT, BTC, ETH, BNB gauges to controller
 * 2. Sets initial gauge weights
 * 3. Activates voting system
 * 
 * After setup, veLVG holders can vote for their preferred gauges
 * to direct LVG emissions to those pools.
 */
contract BootstrapGauges is Script {
    // ============ Deployed Contract ============
    address constant GAUGE_CONTROLLER = 0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5;
    
    // ============ Deployed LendingPool Addresses ============
    address constant POOL_USDT = 0xC57fecAa960Cb9CA70f8C558153314ed17b64c02;
    address constant POOL_BTCB = 0x76CEeC1f498A7D7092922eCA05bdCd6E81E31c4D;
    address constant POOL_ETH  = 0x205ff685b9AA336833C329CE0e731756DB81F527;
    address constant POOL_BNB  = 0x9c72C050C4042fe25E27729B1cc81CDbC7cb3D7B;
    
    // ============ Gauge Names ============
    string constant NAME_USDT = "USDT Lending Pool";
    string constant NAME_BTCB = "BTCB Lending Pool";
    string constant NAME_ETH  = "ETH Lending Pool";
    string constant NAME_BNB  = "BNB Lending Pool";

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== BOOTSTRAP GAUGES ===");
        console.log("Deployer:", deployer);
        console.log("GaugeController:", GAUGE_CONTROLLER);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Add all gauges
        uint256 usdtGauge = _addGauge(POOL_USDT, NAME_USDT);
        uint256 btcbGauge = _addGauge(POOL_BTCB, NAME_BTCB);
        uint256 ethGauge  = _addGauge(POOL_ETH,  NAME_ETH);
        uint256 bnbGauge  = _addGauge(POOL_BNB,  NAME_BNB);
        
        vm.stopBroadcast();
        
        // 2. Print results
        console.log("");
        console.log("--- Gauge IDs ---");
        console.log("USDT Gauge ID:", usdtGauge);
        console.log("BTCB Gauge ID:", btcbGauge);
        console.log("ETH Gauge ID: ", ethGauge);
        console.log("BNB Gauge ID: ", bnbGauge);
        
        // 3. Print all gauges
        _printAllGauges();
        
        console.log("");
        console.log("=== BOOTSTRAP COMPLETE ===");
        console.log("");
        console.log("Next steps:");
        console.log("1. Users lock LVG for veLVG");
        console.log("2. veLVG holders vote for gauges");
        console.log("3. Gauges with more votes receive more LVG emissions");
    }
    
    function _addGauge(address pool, string memory name) internal returns (uint256 gaugeId) {
        console.log("Adding gauge:", name);
        console.log("Pool:", pool);
        
        IGaugeController controller = IGaugeController(GAUGE_CONTROLLER);
        
        // Check for duplicate - iterate existing gauges
        uint256 existingCount = controller.gaugeCount();
        for (uint256 i = 0; i < existingCount; i++) {
            (address existingPool,,,) = controller.gauges(i);
            require(existingPool != pool, "Gauge already exists for this pool");
        }
        
        gaugeId = controller.addGauge(pool, name);
        
        console.log("Gauge ID:", gaugeId);
        console.log("");
    }
    
    function _printAllGauges() internal view {
        console.log("");
        console.log("--- All Gauges ---");
        
        IGaugeController controller = IGaugeController(GAUGE_CONTROLLER);
        uint256 count = controller.gaugeCount();
        
        console.log("Total gauges:", count);
        
        for (uint256 i = 0; i < count; i++) {
            (
                address pool,
                uint256 weight,
                bool active,
                string memory name
            ) = controller.gauges(i);
            
            console.log("");
            console.log("Gauge", i);
            console.log("  Name:", name);
            console.log("  Pool:", pool);
            console.log("  Weight:", weight);
            console.log("  Active:", active);
            
            uint256 relativeWeight = controller.getGaugeRelativeWeight(i);
            console.log("  Relative Weight:", relativeWeight, "bps");
        }
        
        console.log("");
        console.log("Total Votes:", controller.totalVotes());
    }
    
    // ============ Individual Gauge Functions ============
    
    /// @notice Add only USDT gauge
    function addUSDTGauge() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        _addGauge(POOL_USDT, NAME_USDT);
        vm.stopBroadcast();
    }
    
    /// @notice Add only BTCB gauge
    function addBTCBGauge() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        _addGauge(POOL_BTCB, NAME_BTCB);
        vm.stopBroadcast();
    }
    
    /// @notice Add only ETH gauge
    function addETHGauge() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        _addGauge(POOL_ETH, NAME_ETH);
        vm.stopBroadcast();
    }
    
    /// @notice Add only BNB gauge
    function addBNBGauge() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        _addGauge(POOL_BNB, NAME_BNB);
        vm.stopBroadcast();
    }
    
    /// @notice Add custom gauge
    function addCustomGauge(address pool, string calldata name) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        _addGauge(pool, name);
        vm.stopBroadcast();
    }
    
    /// @notice View all gauges (read-only)
    function viewGauges() external view {
        _printAllGauges();
    }
    
    /// @notice Remove a gauge
    function removeGauge(uint256 gaugeId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Removing gauge:", gaugeId);
        
        vm.startBroadcast(deployerPrivateKey);
        IGaugeController(GAUGE_CONTROLLER).removeGauge(gaugeId);
        vm.stopBroadcast();
        
        console.log("Gauge removed!");
    }
}
