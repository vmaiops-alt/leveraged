// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./LVGToken.sol";

/**
 * @title LVGStaking
 * @notice Stake LVG tokens for fee reduction and revenue share
 * @dev Implements tiered benefits based on stake amount
 */
contract LVGStaking {
    
    // ============ Constants ============
    
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant UNSTAKE_COOLDOWN = 7 days;
    
    // Fee reduction tiers (stake amount => fee reduction in BPS)
    uint256 public constant TIER1_STAKE = 1_000 * 1e18;   // 1,000 LVG
    uint256 public constant TIER1_REDUCTION = 2000;       // 20% reduction (25% -> 20%)
    
    uint256 public constant TIER2_STAKE = 5_000 * 1e18;   // 5,000 LVG
    uint256 public constant TIER2_REDUCTION = 3000;       // 30% reduction (25% -> 17.5%)
    
    uint256 public constant TIER3_STAKE = 10_000 * 1e18;  // 10,000 LVG
    uint256 public constant TIER3_REDUCTION = 4000;       // 40% reduction (25% -> 15%)
    
    uint256 public constant TIER4_STAKE = 50_000 * 1e18;  // 50,000 LVG
    uint256 public constant TIER4_REDUCTION = 5000;       // 50% reduction (25% -> 12.5%)
    
    // ============ Structs ============
    
    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 unstakeRequestTime;
        uint256 unstakeAmount;
    }
    
    // ============ State ============
    
    LVGToken public lvgToken;
    address public owner;
    address public feeCollector;
    address public vault;
    
    uint256 public totalStaked;
    uint256 public accRewardPerShare; // Accumulated rewards per share (scaled by 1e12)
    uint256 public lastRewardTime;
    
    // Rewards from fee collector
    address public rewardToken; // Stablecoin
    uint256 public pendingRewards;
    
    mapping(address => StakeInfo) public stakes;
    
    // ============ Events ============
    
    event Staked(address indexed user, uint256 amount);
    event UnstakeRequested(address indexed user, uint256 amount, uint256 unlockTime);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsAdded(uint256 amount);
    
    // ============ Modifiers ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier updateRewards(address user) {
        _updatePool();
        if (user != address(0)) {
            StakeInfo storage userStake = stakes[user];
            if (userStake.amount > 0) {
                uint256 pending = (userStake.amount * accRewardPerShare / 1e12) - userStake.rewardDebt;
                userStake.pendingRewards += pending;
            }
        }
        _;
        if (user != address(0)) {
            stakes[user].rewardDebt = stakes[user].amount * accRewardPerShare / 1e12;
        }
    }
    
    // ============ Constructor ============
    
    constructor(address _lvgToken, address _rewardToken) {
        owner = msg.sender;
        lvgToken = LVGToken(_lvgToken);
        rewardToken = _rewardToken;
        lastRewardTime = block.timestamp;
    }
    
    // ============ Admin Functions ============
    
    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }
    
    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }
    
    // ============ Staking Functions ============
    
    /**
     * @notice Stake LVG tokens
     * @param amount Amount to stake
     */
    function stake(uint256 amount) external updateRewards(msg.sender) {
        require(amount > 0, "Zero amount");
        
        // Transfer LVG from user
        require(lvgToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        stakes[msg.sender].amount += amount;
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @notice Request unstake (starts cooldown)
     * @param amount Amount to unstake
     */
    function requestUnstake(uint256 amount) external updateRewards(msg.sender) {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount >= amount, "Insufficient stake");
        require(amount > 0, "Zero amount");
        
        stakeInfo.unstakeRequestTime = block.timestamp;
        stakeInfo.unstakeAmount = amount;
        
        emit UnstakeRequested(msg.sender, amount, block.timestamp + UNSTAKE_COOLDOWN);
    }
    
    /**
     * @notice Complete unstake after cooldown
     */
    function unstake() external updateRewards(msg.sender) {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.unstakeAmount > 0, "No unstake requested");
        require(block.timestamp >= stakeInfo.unstakeRequestTime + UNSTAKE_COOLDOWN, "Cooldown not passed");
        
        uint256 amount = stakeInfo.unstakeAmount;
        
        stakeInfo.amount -= amount;
        stakeInfo.unstakeAmount = 0;
        stakeInfo.unstakeRequestTime = 0;
        totalStaked -= amount;
        
        // Transfer LVG back to user
        require(lvgToken.transfer(msg.sender, amount), "Transfer failed");
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @notice Claim pending rewards
     */
    function claimRewards() external updateRewards(msg.sender) {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 rewards = stakeInfo.pendingRewards;
        require(rewards > 0, "No rewards");
        
        stakeInfo.pendingRewards = 0;
        
        // Transfer reward tokens
        _transferOut(rewardToken, msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, rewards);
    }
    
    // ============ Fee Collector Integration ============
    
    /**
     * @notice Receive rewards from fee collector
     * @param amount Amount of rewards
     */
    function addRewards(uint256 amount) external {
        require(amount > 0, "Zero amount");
        
        // Transfer from sender
        _transferIn(rewardToken, msg.sender, amount);
        
        pendingRewards += amount;
        emit RewardsAdded(amount);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get user's fee reduction based on stake
     * @param user User address
     * @return reduction Fee reduction in BPS
     */
    function getFeeReduction(address user) external view returns (uint256 reduction) {
        uint256 staked = stakes[user].amount;
        
        if (staked >= TIER4_STAKE) return TIER4_REDUCTION;
        if (staked >= TIER3_STAKE) return TIER3_REDUCTION;
        if (staked >= TIER2_STAKE) return TIER2_REDUCTION;
        if (staked >= TIER1_STAKE) return TIER1_REDUCTION;
        return 0;
    }
    
    /**
     * @notice Get user's staking tier
     * @param user User address
     * @return tier Tier level (0-4)
     */
    function getUserTier(address user) external view returns (uint256 tier) {
        uint256 staked = stakes[user].amount;
        
        if (staked >= TIER4_STAKE) return 4;
        if (staked >= TIER3_STAKE) return 3;
        if (staked >= TIER2_STAKE) return 2;
        if (staked >= TIER1_STAKE) return 1;
        return 0;
    }
    
    /**
     * @notice Get pending rewards for user
     * @param user User address
     * @return pending Pending reward amount
     */
    function getPendingRewards(address user) external view returns (uint256) {
        StakeInfo memory stakeInfo = stakes[user];
        if (stakeInfo.amount == 0) return stakeInfo.pendingRewards;
        
        uint256 accReward = accRewardPerShare;
        if (totalStaked > 0 && pendingRewards > 0) {
            accReward += (pendingRewards * 1e12) / totalStaked;
        }
        
        return stakeInfo.pendingRewards + (stakeInfo.amount * accReward / 1e12) - stakeInfo.rewardDebt;
    }
    
    /**
     * @notice Get user stake info
     * @param user User address
     * @return stakeInfo The stake info struct
     */
    function getStakeInfo(address user) external view returns (StakeInfo memory) {
        return stakes[user];
    }
    
    /**
     * @notice Get staking APR estimate
     * @return apr Annual percentage rate in BPS
     */
    function getEstimatedAPR() external view returns (uint256) {
        if (totalStaked == 0) return 0;
        
        // This is a simplified estimate
        // In production, track actual rewards over time
        uint256 yearlyRewards = pendingRewards * 365; // Rough estimate
        return (yearlyRewards * BPS_DENOMINATOR) / totalStaked;
    }
    
    // ============ Internal Functions ============
    
    function _updatePool() internal {
        if (totalStaked == 0 || pendingRewards == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        
        // Distribute pending rewards
        accRewardPerShare += (pendingRewards * 1e12) / totalStaked;
        pendingRewards = 0;
        lastRewardTime = block.timestamp;
    }
    
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
