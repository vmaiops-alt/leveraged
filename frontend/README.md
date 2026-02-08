# LEVERAGED Frontend

Next.js 14 frontend for the LEVERAGED DeFi platform.

## Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Wallet:** wagmi v2 + RainbowKit v2
- **Styling:** Tailwind CSS
- **State:** TanStack Query
- **Chain:** Viem

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
npm install
```

### Environment Variables

Create `.env.local`:

```env
# WalletConnect Project ID (get from cloud.walletconnect.com)
NEXT_PUBLIC_WC_PROJECT_ID=your_project_id
```

### Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

### Build

```bash
npm run build
npm start
```

## Project Structure

```
src/
├── app/                    # Next.js App Router pages
│   ├── page.tsx           # Dashboard
│   ├── trade/page.tsx     # Open positions
│   ├── positions/page.tsx # View positions
│   ├── earn/page.tsx      # Lending pool
│   ├── stake/page.tsx     # LVG staking
│   ├── layout.tsx         # Root layout
│   └── globals.css        # Global styles
├── components/            # React components
│   └── Navbar.tsx        # Navigation bar
├── hooks/                 # Custom React hooks
│   ├── useVault.ts       # Vault interactions
│   ├── useLendingPool.ts # Lending pool
│   ├── useStaking.ts     # LVG staking
│   └── index.ts          # Exports
├── config/               # Configuration
│   ├── wagmi.ts         # Chain + contract config
│   └── abis.ts          # Contract ABIs
└── lib/                  # Utilities
    └── utils.ts         # Helper functions
```

## Features

### Dashboard (`/`)
- Platform stats (TVL, APY, positions)
- Feature highlights
- How it works section

### Trade (`/trade`)
- Asset selection (BTC, ETH, BNB)
- Leverage slider (1x-5x)
- P&L scenarios
- Risk warnings
- Position summary

### Positions (`/positions`)
- View all open positions
- P&L tracking
- Health factor monitoring
- Add collateral
- Close positions

### Earn (`/earn`)
- Deposit USDT to lending pool
- Withdraw liquidity
- APY display
- Utilization rate

### Stake (`/stake`)
- Stake LVG tokens
- Fee discount tiers
- Claim rewards
- Unstake

## Contract Integration

Update contract addresses in `src/config/wagmi.ts` after deployment:

```typescript
export const CONTRACTS = {
  97: {  // BSC Testnet
    vault: '0x...',
    lendingPool: '0x...',
    feeCollector: '0x...',
    liquidator: '0x...',
    lvgToken: '0x...',
    lvgStaking: '0x...',
    usdt: '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd',
  },
  56: {  // BSC Mainnet
    // ...
  },
}
```

## Hooks Usage

```typescript
import { useOpenPosition, useTokenBalance, useApproveToken } from '@/hooks';

function TradeForm() {
  const { balance } = useTokenBalance(USDT_ADDRESS);
  const { approve, isPending: isApproving } = useApproveToken(USDT_ADDRESS);
  const { openPosition, isPending, isSuccess } = useOpenPosition();

  const handleTrade = async () => {
    await approve('1000');
    await openPosition(WBTC_ADDRESS, '1000', 3); // 3x leverage
  };
}
```

## Styling

Using Tailwind CSS with custom theme in `tailwind.config.js`:

```typescript
colors: {
  primary: '#6366f1',    // Indigo
  secondary: '#22c55e',  // Green
  danger: '#ef4444',     // Red
  dark: {
    100: '#1e1e2e',
    200: '#181825',
    300: '#11111b',
  }
}
```

Custom utility classes in `globals.css`:
- `.card` - Card container
- `.btn`, `.btn-primary`, `.btn-secondary` - Buttons
- `.input` - Form inputs
- `.gradient-text` - Gradient text effect
- `.health-safe`, `.health-warning`, `.health-danger` - Health indicators

## License

UNLICENSED
