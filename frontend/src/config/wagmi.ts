import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { bsc, bscTestnet } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'LEVERAGED',
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID || 'demo',
  chains: [bsc, bscTestnet],
  ssr: true,
});

// Contract addresses (BSC Testnet)
export const CONTRACTS = {
  // Testnet
  97: {
    vault: '0x0000000000000000000000000000000000000000', // Deploy address
    lendingPool: '0x0000000000000000000000000000000000000000',
    feeCollector: '0x0000000000000000000000000000000000000000',
    liquidator: '0x0000000000000000000000000000000000000000',
    lvgToken: '0x0000000000000000000000000000000000000000',
    lvgStaking: '0x0000000000000000000000000000000000000000',
    usdt: '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd',
  },
  // Mainnet
  56: {
    vault: '0x0000000000000000000000000000000000000000',
    lendingPool: '0x0000000000000000000000000000000000000000',
    feeCollector: '0x0000000000000000000000000000000000000000',
    liquidator: '0x0000000000000000000000000000000000000000',
    lvgToken: '0x0000000000000000000000000000000000000000',
    lvgStaking: '0x0000000000000000000000000000000000000000',
    usdt: '0x55d398326f99059fF775485246999027B3197955',
  },
} as const;

// Supported assets
export const ASSETS = {
  WBTC: {
    symbol: 'BTC',
    name: 'Bitcoin',
    icon: '₿',
    address: {
      56: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
      97: '0x0000000000000000000000000000000000000000',
    },
  },
  WETH: {
    symbol: 'ETH',
    name: 'Ethereum',
    icon: 'Ξ',
    address: {
      56: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8',
      97: '0x0000000000000000000000000000000000000000',
    },
  },
  WBNB: {
    symbol: 'BNB',
    name: 'BNB',
    icon: '◈',
    address: {
      56: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
      97: '0x0000000000000000000000000000000000000000',
    },
  },
} as const;
