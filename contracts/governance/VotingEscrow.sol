// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title VotingEscrow
 * @notice Simplified vote-escrowed LVG (veLVG) for governance
 * @dev Lock LVG to get voting power that decays linearly
 */
contract VotingEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ Structs ============
    
    struct Lock {
        uint256 amount;     // Locked LVG amount
        uint256 end;        // Lock end timestamp
        uint256 start;      // Lock start timestamp
    }
    
    // ============ State Variables ============
    
    IERC20 public immutable token;
    uint256 public totalLocked;
    mapping(address => Lock) public locks;
    
    // ============ Constants ============
    
    uint256 public constant WEEK = 7 days;
    uint256 public constant MAX_LOCK = 4 * 365 days;
    uint256 public constant MIN_LOCK = WEEK;
    
    // ============ Delegation ============
    
    /// @notice Delegate mapping: delegator => delegatee
    mapping(address => address) public delegates;
    
    /// @notice Delegated voting power received
    mapping(address => uint256) public delegatedVotingPower;
    
    // ============ Events ============
    
    event Deposited(address indexed user, uint256 amount, uint256 lockEnd);
    event Withdrawn(address indexed user, uint256 amount);
    event LockExtended(address indexed user, uint256 newEnd);
    event AmountIncreased(address indexed user, uint256 addedAmount);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    
    // ============ Errors ============
    
    error ZeroAmount();
    error LockExists();
    error NoLock();
    error LockNotExpired();
    error LockExpired();
    error InvalidLockTime();
    
    // ============ Constructor ============
    
    constructor(address _token) {
        token = IERC20(_token);
    }
    
    // ============ Lock Functions ============
    
    /**
     * @notice Create a new lock
     */
    uint256 public constant MIN_LOCK_AMOUNT = 1e18; // 1 token minimum
    
    function createLock(uint256 _amount, uint256 _unlockTime) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (_amount < MIN_LOCK_AMOUNT) revert ZeroAmount(); // Too small
        if (locks[msg.sender].amount > 0) revert LockExists();
        
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK;
        if (unlockTime <= block.timestamp + MIN_LOCK) revert InvalidLockTime();
        if (unlockTime > block.timestamp + MAX_LOCK) revert InvalidLockTime();
        
        token.safeTransferFrom(msg.sender, address(this), _amount);
        
        locks[msg.sender] = Lock({
            amount: _amount,
            end: unlockTime,
            start: block.timestamp
        });
        
        totalLocked += _amount;
        
        // Update total voting power
        uint256 votePower = this.balanceOf(msg.sender);
        _updateTotalVotingPower(int256(votePower));
        
        emit Deposited(msg.sender, _amount, unlockTime);
    }
    
    /**
     * @notice Increase locked amount
     */
    function increaseAmount(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        
        Lock storage lock = locks[msg.sender];
        if (lock.amount == 0) revert NoLock();
        if (lock.end <= block.timestamp) revert LockExpired();
        
        token.safeTransferFrom(msg.sender, address(this), _amount);
        lock.amount += _amount;
        totalLocked += _amount;
        
        emit AmountIncreased(msg.sender, _amount);
    }
    
    /**
     * @notice Extend lock time
     */
    function extendLock(uint256 _newUnlockTime) external nonReentrant {
        Lock storage lock = locks[msg.sender];
        if (lock.amount == 0) revert NoLock();
        if (lock.end <= block.timestamp) revert LockExpired();
        
        uint256 newEnd = (_newUnlockTime / WEEK) * WEEK;
        if (newEnd <= lock.end) revert InvalidLockTime();
        if (newEnd > block.timestamp + MAX_LOCK) revert InvalidLockTime();
        
        lock.end = newEnd;
        
        emit LockExtended(msg.sender, newEnd);
    }
    
    /**
     * @notice Withdraw after lock expires
     */
    function withdraw() external nonReentrant {
        Lock storage lock = locks[msg.sender];
        if (lock.amount == 0) revert NoLock();
        if (lock.end > block.timestamp) revert LockNotExpired();
        
        uint256 amount = lock.amount;
        totalLocked -= amount;
        
        delete locks[msg.sender];
        
        token.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, amount);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get voting power (linear decay)
     * @dev Power = amount * (timeRemaining / maxLockTime)
     */
    function balanceOf(address _user) external view returns (uint256) {
        Lock storage lock = locks[_user];
        if (lock.amount == 0 || lock.end <= block.timestamp) {
            return 0;
        }
        
        uint256 timeRemaining = lock.end - block.timestamp;
        return (lock.amount * timeRemaining) / MAX_LOCK;
    }
    
    // Track total voting power (updated on lock/unlock/extend)
    uint256 public totalVotingPower;
    
    /**
     * @notice Get total voting power
     * @dev Returns accumulated voting power from all locks
     */
    function totalSupply() external view returns (uint256) {
        return totalVotingPower;
    }
    
    /**
     * @dev Internal function to update total voting power
     */
    function _updateTotalVotingPower(int256 delta) internal {
        if (delta > 0) {
            totalVotingPower += uint256(delta);
        } else if (delta < 0 && totalVotingPower >= uint256(-delta)) {
            totalVotingPower -= uint256(-delta);
        } else {
            totalVotingPower = 0;
        }
    }
    
    /**
     * @notice Get lock details
     */
    function getLock(address _user) external view returns (uint256 amount, uint256 end, uint256 start) {
        Lock storage lock = locks[_user];
        return (lock.amount, lock.end, lock.start);
    }
    
    /**
     * @notice Time until lock expires
     */
    function timeToUnlock(address _user) external view returns (uint256) {
        Lock storage lock = locks[_user];
        if (lock.end <= block.timestamp) return 0;
        return lock.end - block.timestamp;
    }
    
    // ============ Delegation Functions ============
    
    /**
     * @notice Delegate voting power to another address
     * @param _delegatee Address to delegate to (address(0) to remove delegation)
     */
    function delegate(address _delegatee) external {
        address currentDelegate = delegates[msg.sender];
        uint256 votingPower = this.balanceOf(msg.sender);
        
        // Remove power from old delegate
        if (currentDelegate != address(0) && currentDelegate != msg.sender) {
            delegatedVotingPower[currentDelegate] -= votingPower;
        }
        
        // Add power to new delegate
        if (_delegatee != address(0) && _delegatee != msg.sender) {
            delegatedVotingPower[_delegatee] += votingPower;
        }
        
        delegates[msg.sender] = _delegatee;
        
        emit DelegateChanged(msg.sender, currentDelegate, _delegatee);
    }
    
    /**
     * @notice Get total voting power including delegations
     * @param _user Address to check
     */
    function getVotingPower(address _user) external view returns (uint256) {
        uint256 ownPower = this.balanceOf(_user);
        
        // If user has delegated their power away, they have 0 own power
        address userDelegate = delegates[_user];
        if (userDelegate != address(0) && userDelegate != _user) {
            ownPower = 0;
        }
        
        // Add any delegated power received
        return ownPower + delegatedVotingPower[_user];
    }
}
