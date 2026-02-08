# Gas Optimization Guide

## Current Gas Costs (Estimated)

| Function | Estimated Gas | USD @ 5 gwei |
|----------|---------------|--------------|
| openPosition | ~250,000 | ~$0.30 |
| closePosition | ~180,000 | ~$0.22 |
| addCollateral | ~80,000 | ~$0.10 |
| liquidate | ~200,000 | ~$0.24 |
| deposit (lending) | ~100,000 | ~$0.12 |
| withdraw (lending) | ~120,000 | ~$0.15 |
| stake (LVG) | ~90,000 | ~$0.11 |
| unstake (LVG) | ~85,000 | ~$0.10 |
| claimRewards | ~70,000 | ~$0.08 |

*BSC gas prices are typically 3-5 gwei*

## Optimizations Applied

### 1. Storage Packing

```solidity
// Position struct is packed efficiently
struct Position {
    address user;           // 20 bytes
    address asset;          // 20 bytes (slot 1)
    uint96 depositAmount;   // 12 bytes (fits with address, slot 2)
    uint32 leverageMultiplier; // 4 bytes
    uint128 totalExposure;  // 16 bytes (slot 3)
    uint128 borrowedAmount; // 16 bytes (slot 3)
    uint128 entryPrice;     // 16 bytes (slot 4)
    uint64 entryTimestamp;  // 8 bytes (slot 4)
    bool isActive;          // 1 byte (slot 4)
}
```

### 2. Unchecked Arithmetic

Safe unchecked blocks for overflow-impossible operations:

```solidity
// BPS calculations where overflow is impossible
unchecked {
    uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
}
```

### 3. Short-Circuit Evaluation

```solidity
// Check cheapest conditions first
require(amount > 0 && supportedAssets[asset], "Invalid");
```

### 4. Memory vs Storage

```solidity
// Use memory for read-only access
Position memory position = positions[positionId];

// Use storage only when modifying
Position storage position = positions[positionId];
position.isActive = false;
```

### 5. Event Optimization

```solidity
// Index only fields used for filtering
event PositionOpened(
    uint256 indexed positionId,  // Indexed for lookup
    address indexed user,         // Indexed for user queries
    address asset,                // Not indexed (rarely filtered)
    uint256 depositAmount,        // Not indexed
    uint256 leverage,             // Not indexed
    uint256 entryPrice            // Not indexed
);
```

### 6. Batch Operations

```solidity
// Liquidator supports batch liquidation
function batchLiquidate(uint256[] calldata positionIds)
    external 
    returns (uint256 totalDebt, uint256 totalCollateral)
{
    for (uint256 i = 0; i < positionIds.length;) {
        // ... liquidate logic
        unchecked { ++i; }  // Gas savings on increment
    }
}
```

### 7. Calldata vs Memory

```solidity
// Use calldata for read-only array parameters
function batchLiquidate(uint256[] calldata positionIds) // calldata
function processRewards(uint256[] memory amounts)       // memory if modified
```

## Future Optimizations

### 1. EIP-2929 Awareness
First access to storage slot costs 2100 gas, subsequent accesses cost 100.
Group related storage reads together.

### 2. Custom Errors (Solidity 0.8.4+)
```solidity
error InsufficientBalance(uint256 available, uint256 required);

// Instead of
require(balance >= amount, "Insufficient balance");

// Use
if (balance < amount) revert InsufficientBalance(balance, amount);
```

**Gas savings:** ~50 gas per require

### 3. Assembly Optimization
For critical paths, consider inline assembly:

```solidity
function _transferIn(address token, uint256 amount) internal {
    assembly {
        let ptr := mload(0x40)
        mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
        mstore(add(ptr, 4), caller())
        mstore(add(ptr, 36), address())
        mstore(add(ptr, 68), amount)
        let success := call(gas(), token, 0, ptr, 100, 0, 32)
        if iszero(success) { revert(0, 0) }
    }
}
```

### 4. Merkle Proofs for Airdrops
Instead of storing all addresses:
```solidity
function claimAirdrop(bytes32[] calldata proof, uint256 amount) external {
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
    require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");
    // ... claim logic
}
```

## Gas Profiling

### Using Foundry

```bash
# Run gas report
forge test --gas-report

# Snapshot for comparison
forge snapshot

# Compare with previous
forge snapshot --check
```

### Key Metrics to Monitor

1. **openPosition** - Most frequent, optimize first
2. **closePosition** - Second most frequent
3. **liquidate** - Critical for protocol health

## BSC-Specific Considerations

1. **Lower gas prices** - BSC typically 3-5 gwei vs ETH 20-100 gwei
2. **Block gas limit** - 140M on BSC vs 30M on ETH
3. **Faster blocks** - 3s vs 12s, can batch more txs

## Recommendations

1. **Deploy with optimizer:** `--optimizer-runs 200`
2. **Use `immutable` for constructor-set values**
3. **Avoid dynamic arrays in storage when possible**
4. **Pre-calculate constants at compile time**
5. **Use `delete` to clear storage (gas refund)**
