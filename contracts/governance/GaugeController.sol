// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IVotingEscrow {
    function balanceOf(address user) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @title GaugeController
 * @notice Controls reward distribution weights across pools via veLVG voting
 * @dev Users vote for gauges (pools) to direct LVG emissions
 */
contract GaugeController is Ownable {
    
    // ============ Structs ============
    
    struct Gauge {
        address pool;           // Pool/gauge address
        uint256 weight;         // Current weight (basis points)
        bool active;            // Is gauge active
        string name;            // Human-readable name
    }
    
    struct VoteInfo {
        uint256 weight;         // Vote weight in basis points (max 10000)
        uint256 timestamp;      // Last vote timestamp
        uint256 votePowerAtVote; // veLVG balance when vote was cast
    }
    
    // ============ State Variables ============
    
    IVotingEscrow public immutable votingEscrow;
    
    /// @notice All gauges by ID
    mapping(uint256 => Gauge) public gauges;
    
    /// @notice Number of gauges
    uint256 public gaugeCount;
    
    /// @notice User votes per gauge: user => gaugeId => VoteInfo
    mapping(address => mapping(uint256 => VoteInfo)) public userVotes;
    
    /// @notice Total user vote power used (should not exceed 10000 bps)
    mapping(address => uint256) public userVotePowerUsed;
    
    /// @notice Total votes per gauge (sum of all veLVG voting for it)
    mapping(uint256 => uint256) public gaugeVotes;
    
    /// @notice Total votes across all gauges
    uint256 public totalVotes;
    
    /// @notice Vote cooldown period
    uint256 public constant VOTE_COOLDOWN = 10 days;
    
    // ============ Events ============
    
    event GaugeAdded(uint256 indexed gaugeId, address pool, string name);
    event GaugeRemoved(uint256 indexed gaugeId);
    event Voted(address indexed user, uint256 indexed gaugeId, uint256 weight);
    event VoteReset(address indexed user, uint256 indexed gaugeId);
    
    // ============ Errors ============
    
    error GaugeNotFound();
    error GaugeNotActive();
    error NoVotingPower();
    error VoteTooSoon();
    error ExceedsMaxWeight();
    error InvalidWeight();
    
    // ============ Constructor ============
    
    constructor(address _votingEscrow) Ownable(msg.sender) {
        votingEscrow = IVotingEscrow(_votingEscrow);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Add a new gauge
     */
    function addGauge(address _pool, string calldata _name) external onlyOwner returns (uint256 gaugeId) {
        gaugeId = gaugeCount++;
        
        gauges[gaugeId] = Gauge({
            pool: _pool,
            weight: 0,
            active: true,
            name: _name
        });
        
        emit GaugeAdded(gaugeId, _pool, _name);
    }
    
    /**
     * @notice Remove a gauge
     */
    function removeGauge(uint256 _gaugeId) external onlyOwner {
        if (_gaugeId >= gaugeCount) revert GaugeNotFound();
        
        gauges[_gaugeId].active = false;
        
        // Remove gauge votes from total
        totalVotes -= gaugeVotes[_gaugeId];
        gaugeVotes[_gaugeId] = 0;
        
        emit GaugeRemoved(_gaugeId);
    }
    
    // ============ Voting Functions ============
    
    /**
     * @notice Vote for a gauge
     * @param _gaugeId Gauge to vote for
     * @param _weight Weight in basis points (0-10000)
     */
    function vote(uint256 _gaugeId, uint256 _weight) external {
        if (_gaugeId >= gaugeCount) revert GaugeNotFound();
        if (!gauges[_gaugeId].active) revert GaugeNotActive();
        if (_weight > 10000) revert InvalidWeight();
        
        uint256 votePower = votingEscrow.balanceOf(msg.sender);
        if (votePower == 0) revert NoVotingPower();
        
        VoteInfo storage voteInfo = userVotes[msg.sender][_gaugeId];
        
        // Check cooldown
        if (voteInfo.timestamp > 0 && block.timestamp < voteInfo.timestamp + VOTE_COOLDOWN) {
            revert VoteTooSoon();
        }
        
        // Calculate new total used weight
        uint256 newUsedPower = userVotePowerUsed[msg.sender] - voteInfo.weight + _weight;
        if (newUsedPower > 10000) revert ExceedsMaxWeight();
        
        // Update totals using stored vote power for old votes (if exists)
        uint256 oldVotePower = voteInfo.votePowerAtVote > 0 ? voteInfo.votePowerAtVote : votePower;
        uint256 oldVotes = (oldVotePower * voteInfo.weight) / 10000;
        uint256 newVotes = (votePower * _weight) / 10000;
        
        gaugeVotes[_gaugeId] = gaugeVotes[_gaugeId] - oldVotes + newVotes;
        totalVotes = totalVotes - oldVotes + newVotes;
        
        // Update user state with current vote power
        userVotePowerUsed[msg.sender] = newUsedPower;
        voteInfo.weight = _weight;
        voteInfo.timestamp = block.timestamp;
        voteInfo.votePowerAtVote = votePower;
        
        emit Voted(msg.sender, _gaugeId, _weight);
    }
    
    /**
     * @notice Reset vote for a gauge
     */
    function resetVote(uint256 _gaugeId) external {
        VoteInfo storage voteInfo = userVotes[msg.sender][_gaugeId];
        if (voteInfo.weight == 0) return;
        
        // Use stored vote power from when vote was cast (not current decayed power)
        uint256 oldVotePower = voteInfo.votePowerAtVote;
        uint256 oldVotes = (oldVotePower * voteInfo.weight) / 10000;
        
        gaugeVotes[_gaugeId] -= oldVotes;
        totalVotes -= oldVotes;
        
        userVotePowerUsed[msg.sender] -= voteInfo.weight;
        voteInfo.weight = 0;
        voteInfo.votePowerAtVote = 0;
        
        emit VoteReset(msg.sender, _gaugeId);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get gauge weight as percentage of total
     */
    function getGaugeRelativeWeight(uint256 _gaugeId) external view returns (uint256) {
        if (totalVotes == 0) return 0;
        return (gaugeVotes[_gaugeId] * 10000) / totalVotes;
    }
    
    /**
     * @notice Get all gauges
     */
    function getGauges() external view returns (Gauge[] memory) {
        Gauge[] memory result = new Gauge[](gaugeCount);
        for (uint256 i = 0; i < gaugeCount; i++) {
            result[i] = gauges[i];
        }
        return result;
    }
    
    /**
     * @notice Get user's remaining vote power
     */
    function getRemainingVotePower(address _user) external view returns (uint256) {
        return 10000 - userVotePowerUsed[_user];
    }
}
