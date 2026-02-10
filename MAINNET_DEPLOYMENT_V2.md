# LEVERAGED 2.0 - BSC Mainnet Deployment

**Deployed: February 10, 2026**
**Network: BSC Mainnet (Chain ID: 56)**
**Deployer: 0x70ED203A074a916661eF164Bc64Ba7dBa341C664**

## Contract Addresses

| Contract | Address | Description |
|----------|---------|-------------|
| **LVGToken** | `0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1` | Governance token (1B supply) |
| **LVGStaking** | `0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F` | Stake LVG for rewards |
| **LendingPoolV5** | `0x088c08057D51B9C76B06102B95EF0555A1c44507` | Lending with E-Mode |
| **LeveragedFarmV3** | `0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05` | Leveraged yield farming |
| **YieldTokenizer** | `0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605` | PT/YT tokenization |
| **PerpVault** | `0x2911013D3c842420fe5189C9166BDdd8aB6E444E` | Perpetual liquidity vault |
| **PositionManager** | `0xA93c5D73793F000F200B1c92C796207eE1948f50` | Manage perp positions |
| **VotingEscrow** | `0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D` | veLVG locking |
| **GaugeController** | `0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5` | Gauge voting |

## BSCScan Links

- [LVGToken](https://bscscan.com/address/0xdE20645AF3ca7394f6Ca39391650A7CbE49892e1)
- [LVGStaking](https://bscscan.com/address/0xA5293963a65F056E9B0BE0B9bdc4382Ad1C3Ad3F)
- [LendingPoolV5](https://bscscan.com/address/0x088c08057D51B9C76B06102B95EF0555A1c44507)
- [LeveragedFarmV3](https://bscscan.com/address/0x3A7696B0258FE08789bA0F28aD2B4A343eb88F05)
- [YieldTokenizer](https://bscscan.com/address/0x7c01Da2388Eb435588a27ff70163f5fD5d9F3605)
- [PerpVault](https://bscscan.com/address/0x2911013D3c842420fe5189C9166BDdd8aB6E444E)
- [PositionManager](https://bscscan.com/address/0xA93c5D73793F000F200B1c92C796207eE1948f50)
- [VotingEscrow](https://bscscan.com/address/0xcE1909FE4354D2ed9d0d3b50Db61090768C4459D)
- [GaugeController](https://bscscan.com/address/0x30c11358E452c7b2B8C189b2aeAaf8a598Ebf0E5)

## Features

### Core
- **Lending Pool V5**: E-Mode for correlated assets, improved interest rate model
- **Leveraged Farm V3**: Up to 5x leverage with liquidation protection

### LEVERAGED 2.0 Features
- **Yield Tokenization**: Split yield-bearing assets into PT (Principal) + YT (Yield)
- **Perpetual Trading**: Up to 50x leverage on BTC, ETH, BNB
- **Governance**: Vote-escrowed LVG (veLVG) with gauge voting

## Verification Status
⚠️ BSCScan API v2 migration required - manual verification pending

## Legacy Contracts (V1)
| Contract | Address |
|----------|---------|
| LVGToken (old) | `0x17D2b7C19578478a867b68eAdcE61f0c546f00Ea` |
| LVGStaking (old) | `0xE6f9eDA0344e0092a6c6Bb8f6D29112646821cf2` |
| LeveragedFarmV3 (old) | `0xF8d55820fe61FAD64D90270032Ed310B3b28e30d` |
| LendingPoolV4 (old) | `0xC57fecAa960Cb9CA70f8C558153314ed17b64c02` |
