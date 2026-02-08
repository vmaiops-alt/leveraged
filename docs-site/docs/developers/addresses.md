# Contract Addresses

## BSC Testnet (Chain ID: 97)

| Contract | Address |
|----------|---------|
| LeveragedVault | `0xE163112607794a73281Cb390ae9FC30f3287A7D8` |
| LendingPool | `0xCE066289D798300ceFCC1B6FdEa5dD10AF113486` |
| PriceOracle | `0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee` |
| ValueTracker | `0xC080c0F2a33cDa382fcF3064fA9232Cf09273511` |
| FeeCollector | `0x77D8AfD4dB7a29c26d297E021C9C24E9187B6f77` |
| Liquidator | `0xc3C7265C547e9a4040A671E6561f4a2f3dE99c87` |
| LVGToken | `0xBA32bF5e975a53832EB757475B4a620B3219bB01` |
| LVGStaking | `0xB837bbcf932D8156B9fe5d06a496e54aF18EBa15` |

### External Contracts (Testnet)

| Contract | Address |
|----------|---------|
| USDT | `0x337610d27c682E347C9cD60BD4b3b107C9d34dDd` |
| Chainlink BTC/USD | `0x5741306c21795FdCBb9b265Ea0255F499DFe515C` |
| Chainlink ETH/USD | `0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7` |
| Chainlink BNB/USD | `0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526` |

## BSC Mainnet (Chain ID: 56)

{% hint style="warning" %}
Mainnet contracts not yet deployed. Coming after audit completion.
{% endhint %}

| Contract | Address |
|----------|---------|
| LeveragedVault | TBD |
| LendingPool | TBD |
| PriceOracle | TBD |
| ValueTracker | TBD |
| FeeCollector | TBD |
| Liquidator | TBD |
| LVGToken | TBD |
| LVGStaking | TBD |

### External Contracts (Mainnet)

| Contract | Address |
|----------|---------|
| USDT | `0x55d398326f99059fF775485246999027B3197955` |
| WBTC | `0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c` |
| WETH | `0x2170Ed0880ac9A755fd29B2688956BD959F933F8` |
| WBNB | `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c` |
| Chainlink BTC/USD | `0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf` |
| Chainlink ETH/USD | `0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e` |
| Chainlink BNB/USD | `0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE` |

## Verifying Contracts

All contracts can be verified on BscScan:

**Testnet:** [testnet.bscscan.com](https://testnet.bscscan.com)
**Mainnet:** [bscscan.com](https://bscscan.com)

### Verification Command

```bash
forge verify-contract <ADDRESS> <CONTRACT> \
  --chain-id 97 \
  --etherscan-api-key $BSCSCAN_API_KEY
```

## Adding Tokens to Wallet

### LVG Token (Testnet)

To add LVG to MetaMask:

1. Open MetaMask
2. Click "Import tokens"
3. Enter: `0xBA32bF5e975a53832EB757475B4a620B3219bB01`
4. Symbol: `LVG`
5. Decimals: `18`
