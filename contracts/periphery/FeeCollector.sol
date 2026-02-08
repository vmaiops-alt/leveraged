// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../interfaces/IFeeCollector.sol";

/**
 * @title FeeCollector
 * @notice Collects and distributes platform fees
 * @dev Handles treasury, insurance fund, and staker distributions
 */
contract FeeCollector is IFeeCollector {
    
    // ============ Constants ============
    
    uint256 public constant BPS_DENOMINATOR = 10000;
    
    // Fee distribution ratios (must sum to 10000)
    uint256 public constant TREASURY_RATIO = 6000;    // 60% to treasury
    uint256 public constant INSURANCE_RATIO = 1000;   // 10% to insurance fund
    uint256 public constant STAKER_RATIO = 3000;      // 30% to LVG stakers
    
    // ============ State ============
    
    address public owner;
    address public vault;
    
    address public treasury;
    address public insuranceFund;
    address public stakingContract;
    
    mapping(address => uint256) public pendingFees; // token => amount
    mapping(address => uint256) public totalCollected; // token => total
    mapping(string => uint256) public feesByType; // feeType => total
    
    // ============ Events ============
    
    event VaultSet(address indexed vault);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVault() {
        require(msg.sender == vault, "Not vault");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address _treasury) {
        owner = msg.sender;
        treasury = _treasury;
        insuranceFund = _treasury; // Initially same as treasury
    }
    
    // ============ Admin Functions ============
    
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        vault = _vault;
        emit VaultSet(_vault);
    }
    
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }
    
    function setInsuranceFund(address _insuranceFund) external onlyOwner {
        require(_insuranceFund != address(0), "Invalid insurance fund");
        insuranceFund = _insuranceFund;
        emit InsuranceFundSet(_insuranceFund);
    }
    
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid staking contract");
        stakingContract = _stakingContract;
        emit StakingContractSet(_stakingContract);
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Collect fees (called by vault or directly via transfer)
     * @param token The token address
     * @param amount Amount of fees
     * @param feeType Type of fee
     */
    function collectFees(
        address token, 
        uint256 amount, 
        string calldata feeType
    ) external override {
        require(amount > 0, "Zero amount");
        
        // Transfer tokens from sender
        _transferIn(token, msg.sender, amount);
        
        // Track fees
        pendingFees[token] += amount;
        totalCollected[token] += amount;
        feesByType[feeType] += amount;
        
        emit FeesCollected(token, amount, feeType);
    }
    
    /**
     * @notice Receive fees directly (for vault integration)
     */
    function receiveFees(address token, uint256 amount) external {
        pendingFees[token] += amount;
        totalCollected[token] += amount;
        emit FeesCollected(token, amount, "direct");
    }
    
    /**
     * @notice Distribute collected fees to recipients
     */
    function distributeFees() external override {
        // This would iterate through tokens, but for simplicity
        // we assume stablecoin (can be extended)
    }
    
    /**
     * @notice Distribute fees for a specific token
     * @param token The token to distribute
     */
    function distributeFeesForToken(address token) external {
        uint256 amount = pendingFees[token];
        require(amount > 0, "No pending fees");
        
        // Calculate distributions
        uint256 toTreasury = (amount * TREASURY_RATIO) / BPS_DENOMINATOR;
        uint256 toInsurance = (amount * INSURANCE_RATIO) / BPS_DENOMINATOR;
        uint256 toStakers = amount - toTreasury - toInsurance; // Remainder to stakers
        
        // Reset pending
        pendingFees[token] = 0;
        
        // Transfer to treasury
        if (toTreasury > 0 && treasury != address(0)) {
            _transferOut(token, treasury, toTreasury);
        }
        
        // Transfer to insurance fund
        if (toInsurance > 0 && insuranceFund != address(0)) {
            _transferOut(token, insuranceFund, toInsurance);
        }
        
        // Transfer to staking contract for distribution
        if (toStakers > 0 && stakingContract != address(0)) {
            _transferOut(token, stakingContract, toStakers);
            // Staking contract should have a function to notify of new rewards
        }
        
        emit FeesDistributed(toTreasury, toInsurance, toStakers);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get pending fees for distribution
     * @param token The token address
     * @return pending Pending fee amount
     */
    function getPendingFees(address token) external view override returns (uint256) {
        return pendingFees[token];
    }
    
    /**
     * @notice Get fee distribution ratios
     */
    function getFeeRatios() external pure override returns (
        uint256 treasuryRatio,
        uint256 insuranceRatio,
        uint256 stakerRatio
    ) {
        return (TREASURY_RATIO, INSURANCE_RATIO, STAKER_RATIO);
    }
    
    /**
     * @notice Get total fees collected for a token
     * @param token The token address
     * @return total Total collected
     */
    function getTotalCollected(address token) external view returns (uint256) {
        return totalCollected[token];
    }
    
    /**
     * @notice Get fees collected by type
     * @param feeType The fee type
     * @return total Total collected for type
     */
    function getFeesByType(string calldata feeType) external view returns (uint256) {
        return feesByType[feeType];
    }
    
    // ============ Emergency Functions ============
    
    /**
     * @notice Emergency withdraw (owner only)
     * @param token Token to withdraw
     * @param to Recipient
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(
        address token, 
        address to, 
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        _transferOut(token, to, amount);
    }
    
    // ============ Internal Functions ============
    
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
}
