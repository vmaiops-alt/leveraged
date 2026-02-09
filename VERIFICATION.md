# Contract Verification Guide

## Deployed Contracts (BSC Testnet)

| Contract | Address |
|----------|---------|
| LeveragedVault | `0xE163112607794a73281Cb390ae9FC30f3287A7D8` |
| LendingPool | `0xCE066289D798300ceFCC1B6FdEa5dD10AF113486` |
| LVGToken | `0xBA32bF5e975a53832EB757475B4a620B3219bB01` |
| LVGStaking | `0xB837bbcf932D8156B9fe5d06a496e54aF18EBa15` |
| PriceOracle | `0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee` |
| FeeCollector | `0x77D8AfD4dB7a29c26d297E021C9C24E9187B6f77` |
| Liquidator | `0xc3C7265C547e9a4040A671E6561f4a2f3dE99c87` |
| ValueTracker | `0xC080c0F2a33cDa382fcF3064fA9232Cf09273511` |

## Verification Steps

### 1. Get BSCScan API Key
1. Register at https://bscscan.com/register
2. Go to https://bscscan.com/myapikey
3. Create new API key

### 2. Add to .env
```bash
BSCSCAN_API_KEY=your_api_key_here
```

### 3. Run Verification

```bash
# LVG Token
forge verify-contract \
  --chain-id 97 \
  --watch \
  --constructor-args $(cast abi-encode "constructor()") \
  0xBA32bF5e975a53832EB757475B4a620B3219bB01 \
  contracts/token/LVGToken.sol:LVGToken

# LVG Staking
forge verify-contract \
  --chain-id 97 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address)" 0xBA32bF5e975a53832EB757475B4a620B3219bB01) \
  0xB837bbcf932D8156B9fe5d06a496e54aF18EBa15 \
  contracts/token/LVGStaking.sol:LVGStaking

# Price Oracle
forge verify-contract \
  --chain-id 97 \
  --watch \
  --constructor-args $(cast abi-encode "constructor()") \
  0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee \
  contracts/core/PriceOracle.sol:PriceOracle

# Lending Pool
forge verify-contract \
  --chain-id 97 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address)" 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd) \
  0xCE066289D798300ceFCC1B6FdEa5dD10AF113486 \
  contracts/core/LendingPool.sol:LendingPool

# Leveraged Vault
forge verify-contract \
  --chain-id 97 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd 0xCE066289D798300ceFCC1B6FdEa5dD10AF113486 0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee) \
  0xE163112607794a73281Cb390ae9FC30f3287A7D8 \
  contracts/core/LeveragedVault.sol:LeveragedVault
```

### 4. Manual Verification (Alternative)

Go to BSCScan contract page → "Contract" tab → "Verify and Publish"

1. Compiler: v0.8.20
2. Optimization: Enabled (200 runs)
3. License: MIT
4. Flatten the contract first: `forge flatten contracts/core/LeveragedVault.sol > flat_LeveragedVault.sol`

## Links

- [LeveragedVault on BSCScan](https://testnet.bscscan.com/address/0xE163112607794a73281Cb390ae9FC30f3287A7D8)
- [LVGToken on BSCScan](https://testnet.bscscan.com/address/0xBA32bF5e975a53832EB757475B4a620B3219bB01)
- [LVGStaking on BSCScan](https://testnet.bscscan.com/address/0xB837bbcf932D8156B9fe5d06a496e54aF18EBa15)
