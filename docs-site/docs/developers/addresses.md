# Contract Addresses

## BSC Mainnet (Chain ID: 56)

| Contract | Address |
|----------|---------|
| LeveragedFarmV5 | `0xdcfFA96A8440C9d027C530FCA5b93e695f6c0574` |
| LendingPoolV4 | `0xC57fecAa960Cb9CA70f8C558153314ed17b64c02` |
| LVGToken | `0x17D2b7C19578478a867b68eAdcE61f0c546f00Ea` |
| LVGStaking | `0xE6f9eDA0344e0092a6c6Bb8f6D29112646821cf2` |

### External Contracts (Mainnet)

| Contract | Address |
|----------|---------|
| USDT | `0x55d398326f99059fF775485246999027B3197955` |
| WBNB | `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c` |
| CAKE | `0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82` |
| PancakeSwap Router | `0x10ED43C718714eb63d5aA57B78B54704E256024E` |
| MasterChef V2 | `0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652` |
| Chainlink BNB/USD | `0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE` |

### LP Token Addresses (PancakeSwap V2)

| Pool | LP Token |
|------|----------|
| USDT-BNB | `0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE` |
| CAKE-BNB | `0x0eD7e52944161450477ee417DE9Cd3a859b14fD0` |
| ETH-BNB | `0x74E4716E431f45807DCF19f284c7aA99F18a4fbc` |
| BTCB-BNB | `0x61EB789d75A95CAa3fF50ed7E47b96c132fEc082` |

## Verifying Contracts

All contracts can be verified on BscScan:

**Mainnet:** [bscscan.com](https://bscscan.com)

### View Contract
```
https://bscscan.com/address/0xdcfFA96A8440C9d027C530FCA5b93e695f6c0574#code
```

## Adding Tokens to Wallet

### LVG Token (Mainnet)

To add LVG to MetaMask:

1. Open MetaMask
2. Click "Import tokens"
3. Enter: `0x17D2b7C19578478a867b68eAdcE61f0c546f00Ea`
4. Symbol: `LVG`
5. Decimals: `18`

## Fee Contract Functions

### LeveragedFarmV5

```solidity
// Fee constants (in basis points)
OPEN_FEE_BPS = 10          // 0.1%
CLOSE_FEE_BPS = 10         // 0.1%
PERFORMANCE_FEE_BPS = 1000 // 10%
APPRECIATION_FEE_BPS = 2500 // 25%
LIQUIDATION_FEE_BPS = 100  // 1%
```

### LVGStaking Discount Tiers

```solidity
// Staking tiers and discounts
1,000 LVG  → 20% discount (2000 BPS)
5,000 LVG  → 30% discount (3000 BPS)
10,000 LVG → 40% discount (4000 BPS)
50,000 LVG → 50% discount (5000 BPS)
```
