# BSC Mainnet Deployment

**Date:** 2026-02-09
**Network:** BNB Smart Chain (Chain ID: 56)

## Deployed Contracts

### Auto-Compounding Venus Vaults

| Vault | Address | Underlying | Strategy |
|-------|---------|------------|----------|
| Venus USDT | `0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee` | USDT | Venus lending + XVS rewards |
| Venus BUSD | `0x1D26Be0b284C594B3b53E9856419AE0dA59ECb68` | BUSD | Venus lending + XVS rewards |
| Venus USDC | `0x131A3B5355a289EEBF8BF6Df29Cdad87A34EA50e` | USDC | Venus lending + XVS rewards |
| Venus BNB | `0x432E83EBcF26067357d94c601412018CfDDd4605` | BNB | Venus lending + XVS rewards |

### Treasury

- Address: `0x70ED203A074a916661eF164Bc64Ba7dBa341C664`
- Receives performance fees (5%) and withdrawal fees (0.1%)

## Fee Structure

- **Performance Fee:** 5% (taken from XVS rewards only)
- **Withdrawal Fee:** 0.1%

## How It Works

1. User deposits token (USDT/BUSD/USDC/BNB)
2. Vault deposits into Venus Protocol
3. Vault earns:
   - Base interest from Venus lending
   - XVS rewards from Venus
4. Anyone can call `harvest()` to:
   - Claim XVS rewards
   - Take 5% performance fee
   - Swap remaining XVS → underlying token
   - Re-deposit into Venus (auto-compound)
5. User withdraws anytime (0.1% fee)

## Venus Protocol Integration

| Token | vToken Address |
|-------|----------------|
| USDT | `0xfD5840Cd36d94D7229439859C0112a4185BC0255` |
| BUSD | `0x95c78222B3D6e262426483D42CfA53685A67Ab9D` |
| USDC | `0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8` |
| BNB | `0xA07c5b74C9B40447a954e1466938b865b6BBea36` |

Comptroller: `0xfD36E2c2a6789Db23113685031d7F16329158384`

## BSCScan Links

- [USDT Vault](https://bscscan.com/address/0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee)
- [BUSD Vault](https://bscscan.com/address/0x1D26Be0b284C594B3b53E9856419AE0dA59ECb68)
- [USDC Vault](https://bscscan.com/address/0x131A3B5355a289EEBF8BF6Df29Cdad87A34EA50e)
- [BNB Vault](https://bscscan.com/address/0x432E83EBcF26067357d94c601412018CfDDd4605)

## Frontend

- **Live:** https://leveraged-app.vercel.app
- **Default Network:** BSC Mainnet
