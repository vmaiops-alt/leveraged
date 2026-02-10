// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../interfaces/IFeeCollector.sol";

/**
 * @title FeeCollector
 * @notice Collects and distributes protocol fees for LEVERAGED
 * @dev Handles fee accumulation, distribution to treasury/insurance/stakers
 */
contract FeeCollector is IFeeCollector {
    
    // ============ Constants ============
    
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MIN_DISTRIBUTION_AMOUNT = 100e6; // 100 USDT/USDC (6 decimals)
    
    // ============ State ============
    
    address public owner;
    address public vault; // Only vault can collect fees
    
    // Distribution recipients
    address public treasury;
    address public insuranceFund;
    address public stakingContract;
    
    // Distribution ratios (must sum to BPS_DENOMINATOR)
    uint256 public treasuryRatioBPS;   // Protocol treasury
    uint256 public insuranceRatioBPS;  // Insurance fund for bad debt
    uint256 public stakerRatioBPS;     // $LVG stakers
    
    // Pending fees per token
    mapping(address => uint256) public pendingFees;
    
    // Cumulative stats per fee type
    mapping(string => uint256) public totalFeesByType;
    
    // Supported tokens for fee collection
    mapping(address => bool) public supportedTokens;
    address[] public tokenList;
    
    bool public paused;
    
    // ============ Events ============
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event VaultSet(address indexed vault);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event FeeRatiosUpdated(uint256 treasury, uint256 insurance, uint256 staker);
    event TokenSupported(address indexed token, bool supported);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed to);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyVault() {
        require(msg.sender == vault, "Not vault");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _treasury,
        address _insuranceFund,
        address _stakingContract
    ) {
        require(_treasury != address(0), "Invalid treasury");
        
        owner = msg.sender;
        treasury = _treasury;
        insuranceFund = _insuranceFund;
        stakingContract = _stakingContract;
        
        // Default ratios: 50% treasury, 30% insurance, 20% stakers
        treasuryRatioBPS = 5000;
        insuranceRatioBPS = 3000;
        stakerRatioBPS = 2000;
    }
    
    // ============ Admin Functions ============
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
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
        insuranceFund = _insuranceFund;
        emit InsuranceFundSet(_insuranceFund);
    }
    
    function setStakingContract(address _stakingContract) external onlyOwner {
        stakingContract = _stakingContract;
        emit StakingContractSet(_stakingContract);
    }
    
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }
    
    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
    
    /**
     * @notice Update fee distribution ratios
     * @param _treasuryRatio Treasury ratio in BPS
     * @param _insuranceRatio Insurance fund ratio in BPS
     * @param _stakerRatio Staker ratio in BPS
     */
    function setFeeRatios(
        uint256 _treasuryRatio,
        uint256 _insuranceRatio,
        uint256 _stakerRatio
    ) external onlyOwner {
        require(
            _treasuryRatio + _insuranceRatio + _stakerRatio == BPS_DENOMINATOR,
            "Ratios must sum to 10000"
        );
        
        treasuryRatioBPS = _treasuryRatio;
        insuranceRatioBPS = _insuranceRatio;
        stakerRatioBPS = _stakerRatio;
        
        emit FeeRatiosUpdated(_treasuryRatio, _insuranceRatio, _stakerRatio);
    }
    
    /**
     * @notice Add supported token for fee collection
     * @param token Token address
     */
    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!supportedTokens[token], "Already supported");
        
        supportedTokens[token] = true;
        tokenList.push(token);
        
        emit TokenSupported(token, true);
    }
    
    /**
     * @notice Remove supported token
     * @param token Token address
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token], "Not supported");
        
        supportedTokens[token] = false;
        
        // Remove from list
        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
        
        emit TokenSupported(token, false);
    }
    
    /**
     * @notice Emergency withdraw (for stuck tokens)
     * @param token Token address
     * @param to Recipient
     */
    function emergencyWithdraw(address token, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        
        uint256 balance = _getTokenBalance(token);
        require(balance > 0, "No balance");
        
        _transferToken(token, to, balance);
        pendingFees[token] = 0;
        
        emit EmergencyWithdraw(token, balance, to);
    }
    
    // ============ Core Functions ============
    
    /**
     * @notice Collect fees from vault
     * @param token The token address
     * @param amount Amount of fees
     * @param feeType Type of fee (valueIncrease, performance, entry, liquidation)
     */
    function collectFees(
        address token, 
        uint256 amount, 
        string calldata feeType
    ) external override onlyVault whenNotPaused {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Zero amount");
        
        // Fee should already be transferred to this contract by vault
        pendingFees[token] += amount;
        totalFeesByType[feeType] += amount;
        
        emit FeesCollected(token, amount, feeType);
    }
    
    /**
     * @notice Distribute collected fees to recipients
     * @dev Can be called by anyone (keeper incentivized by gas refund from treasury)
     */
    function distributeFees() external override whenNotPaused {
        bool distributed = false;
        
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            uint256 pending = pendingFees[token];
            
            if (pending >= MIN_DISTRIBUTION_AMOUNT) {
                _distributeToken(token, pending);
                pendingFees[token] = 0;
                distributed = true;
            }
        }
        
        require(distributed, "Nothing to distribute");
    }
    
    /**
     * @notice Distribute fees for a specific token
     * @param token Token to distribute
     */
    function distributeToken(address token) external whenNotPaused {
        require(supportedTokens[token], "Token not supported");
        
        uint256 pending = pendingFees[token];
        require(pending >= MIN_DISTRIBUTION_AMOUNT, "Below minimum");
        
        _distributeToken(token, pending);
        pendingFees[token] = 0;
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
     * @notice Get total pending fees across all tokens
     * @return total Total pending fees (approximate, assumes same decimals)
     */
    function getTotalPendingFees() external view returns (uint256 total) {
        for (uint256 i = 0; i < tokenList.length; i++) {
            total += pendingFees[tokenList[i]];
        }
    }
    
    /**
     * @notice Get fee distribution ratios
     * @return treasuryRatio Treasury ratio in BPS
     * @return insuranceRatio Insurance fund ratio in BPS
     * @return stakerRatio Staker ratio in BPS
     */
    function getFeeRatios() external view override returns (
        uint256 treasuryRatio,
        uint256 insuranceRatio,
        uint256 stakerRatio
    ) {
        return (treasuryRatioBPS, insuranceRatioBPS, stakerRatioBPS);
    }
    
    /**
     * @notice Get all supported tokens
     * @return Array of token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return tokenList;
    }
    
    /**
     * @notice Get total fees collected by type
     * @param feeType Type of fee
     * @return Total amount collected
     */
    function getTotalFeesByType(string calldata feeType) external view returns (uint256) {
        return totalFeesByType[feeType];
    }
    
    /**
     * @notice Preview distribution amounts
     * @param token Token address
     * @return toTreasury Amount to treasury
     * @return toInsurance Amount to insurance fund
     * @return toStakers Amount to stakers
     */
    function previewDistribution(address token) external view returns (
        uint256 toTreasury,
        uint256 toInsurance,
        uint256 toStakers
    ) {
        uint256 pending = pendingFees[token];
        if (pending == 0) return (0, 0, 0);
        
        toTreasury = (pending * treasuryRatioBPS) / BPS_DENOMINATOR;
        toInsurance = (pending * insuranceRatioBPS) / BPS_DENOMINATOR;
        toStakers = pending - toTreasury - toInsurance; // Remainder to stakers to avoid rounding loss
    }
    
    // ============ Internal Functions ============
    
    function _distributeToken(address token, uint256 amount) internal {
        uint256 toTreasury = (amount * treasuryRatioBPS) / BPS_DENOMINATOR;
        uint256 toInsurance = (amount * insuranceRatioBPS) / BPS_DENOMINATOR;
        uint256 toStakers = amount - toTreasury - toInsurance; // Remainder to avoid rounding loss
        
        // Transfer to treasury (always exists)
        if (toTreasury > 0) {
            _transferToken(token, treasury, toTreasury);
        }
        
        // Transfer to insurance fund (if set)
        if (toInsurance > 0 && insuranceFund != address(0)) {
            _transferToken(token, insuranceFund, toInsurance);
        } else if (toInsurance > 0) {
            // If no insurance fund, send to treasury
            _transferToken(token, treasury, toInsurance);
            toTreasury += toInsurance;
            toInsurance = 0;
        }
        
        // Transfer to staking contract (if set)
        if (toStakers > 0 && stakingContract != address(0)) {
            _transferToken(token, stakingContract, toStakers);
        } else if (toStakers > 0) {
            // If no staking contract, send to treasury
            _transferToken(token, treasury, toStakers);
            toTreasury += toStakers;
            toStakers = 0;
        }
        
        emit FeesDistributed(toTreasury, toInsurance, toStakers);
    }
    
    function _transferToken(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }
    
    function _getTokenBalance(address token) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        require(success && data.length >= 32, "Balance check failed");
        return abi.decode(data, (uint256));
    }
}
