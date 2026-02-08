import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { bsc, bscTestnet } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'LEVERAGED',
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID || 'demo',
  chains: [bsc, bscTestnet],
  ssr: true,
});

// Contract addresses
export const CONTRACTS = {
  // BSC Testnet (Chain ID: 97)
  97: {
    vault: '0xE163112607794a73281Cb390ae9FC30f3287A7D8',
    lendingPool: '0xCE066289D798300ceFCC1B6FdEa5dD10AF113486',
    feeCollector: '0x77D8AfD4dB7a29c26d297E021C9C24E9187B6f77',
    liquidator: '0xc3C7265C547e9a4040A671E6561f4a2f3dE99c87',
    lvgToken: '0xBA32bF5e975a53832EB757475B4a620B3219bB01',
    lvgStaking: '0xB837bbcf932D8156B9fe5d06a496e54aF18EBa15',
    priceOracle: '0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee',
    valueTracker: '0xC080c0F2a33cDa382fcF3064fA9232Cf09273511',
    usdt: '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd',
  },
  // BSC Mainnet (Chain ID: 56) - TODO: Deploy
  56: {
    vault: '0x0000000000000000000000000000000000000000',
    lendingPool: '0x0000000000000000000000000000000000000000',
    feeCollector: '0x0000000000000000000000000000000000000000',
    liquidator: '0x0000000000000000000000000000000000000000',
    lvgToken: '0x0000000000000000000000000000000000000000',
    lvgStaking: '0x0000000000000000000000000000000000000000',
    priceOracle: '0x0000000000000000000000000000000000000000',
    valueTracker: '0x0000000000000000000000000000000000000000',
    usdt: '0x55d398326f99059fF775485246999027B3197955',
  },
} as const;

// Supported assets for leveraged trading
export const ASSETS = {
  WBTC: {
    symbol: 'BTC',
    name: 'Bitcoin',
    icon: '₿',
    address: {
      56: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
      97: '0x0000000000000000000000000000000000000001', // Mock address for testnet
    },
  },
  WETH: {
    symbol: 'ETH',
    name: 'Ethereum',
    icon: 'Ξ',
    address: {
      56: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8',
      97: '0x0000000000000000000000000000000000000002', // Mock address for testnet
    },
  },
  WBNB: {
    symbol: 'BNB',
    name: 'BNB',
    icon: '◈',
    address: {
      56: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
      97: '0x0000000000000000000000000000000000000003', // Mock address for testnet
    },
  },
} as const;

// Chain config
export const SUPPORTED_CHAINS = [97, 56] as const;
export const DEFAULT_CHAIN = 97; // Default to testnet for now
