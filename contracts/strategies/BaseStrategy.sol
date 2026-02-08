// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/IStrategy.sol";

/**
 * @title BaseStrategy
 * @notice Abstract base contract for yield strategies
 */
abstract contract BaseStrategy is IStrategy {
    
    // ============ State ============
    
    address public owner;
    address public vault;
    address public override asset;
    
    uint256 public totalShares;
    mapping(address => uint256) public userShares;
    
    bool public paused;
    
    // ============ Events ============
    
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);
    event Harvested(uint256 amount);
    event Paused();
    event Unpaused();
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVault() {
        require(msg.sender == vault || msg.sender == owner, "Not vault");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _asset) {
        owner = msg.sender;
        asset = _asset;
    }
    
    // ============ Admin ============
    
    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }
    
    function pause() external onlyOwner {
        paused = true;
        emit Paused();
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }
    
    // ============ Internal Helpers ============
    
    function _transferIn(address token, address from, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer in failed");
    }
    
    function _transferOut(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer out failed");
    }
    
    function _approve(address token, address spender, uint256 amount) internal {
        (bool success, ) = token.call(
            abi.encodeWithSignature("approve(address,uint256)", spender, amount)
        );
        require(success, "Approve failed");
    }
    
    function _balanceOf(address token) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        require(success, "Balance check failed");
        return abi.decode(data, (uint256));
    }
}
