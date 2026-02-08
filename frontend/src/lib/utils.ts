import { formatUnits, parseUnits } from 'viem';

/**
 * Format a number with commas and optional decimals
 */
export function formatNumber(value: number | string, decimals: number = 2): string {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  if (isNaN(num)) return '0';
  
  return num.toLocaleString('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}

/**
 * Format a number as USD currency
 */
export function formatUSD(value: number | string, decimals: number = 2): string {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  if (isNaN(num)) return '$0.00';
  
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(num);
}

/**
 * Format a bigint token amount to human readable string
 */
export function formatTokenAmount(amount: bigint | undefined, decimals: number = 18, displayDecimals: number = 2): string {
  if (!amount) return '0';
  const formatted = formatUnits(amount, decimals);
  return formatNumber(formatted, displayDecimals);
}

/**
 * Parse a human readable string to bigint token amount
 */
export function parseTokenAmount(amount: string, decimals: number = 18): bigint {
  try {
    return parseUnits(amount, decimals);
  } catch {
    return BigInt(0);
  }
}

/**
 * Shorten an address for display
 */
export function shortenAddress(address: string, chars: number = 4): string {
  if (!address) return '';
  return `${address.slice(0, chars + 2)}...${address.slice(-chars)}`;
}

/**
 * Format a health factor with appropriate color class
 */
export function getHealthFactorClass(healthFactor: number): string {
  if (healthFactor > 1.5) return 'text-green-400';
  if (healthFactor > 1.1) return 'text-yellow-400';
  return 'text-red-400';
}

/**
 * Calculate liquidation price drop percentage
 */
export function getLiquidationDrop(leverage: number): number {
  // Rough estimate: liquidation happens when health factor drops below 1.1
  // At 5x leverage, ~17% drop liquidates
  // At 2x leverage, ~42% drop liquidates
  return (100 / leverage) * 0.85;
}

/**
 * Calculate estimated P&L for a price change
 */
export function calculatePnL(
  deposit: number,
  leverage: number,
  priceChangePercent: number,
  feePercent: number = 25
): {
  grossPnL: number;
  fee: number;
  netPnL: number;
  netPnLPercent: number;
} {
  const leveragedChange = priceChangePercent * leverage;
  const grossPnL = deposit * (leveragedChange / 100);
  const fee = grossPnL > 0 ? grossPnL * (feePercent / 100) : 0;
  const netPnL = grossPnL - fee;
  const netPnLPercent = deposit > 0 ? (netPnL / deposit) * 100 : 0;

  return {
    grossPnL,
    fee,
    netPnL,
    netPnLPercent,
  };
}

/**
 * Format a percentage
 */
export function formatPercent(value: number, decimals: number = 2): string {
  return `${value >= 0 ? '+' : ''}${value.toFixed(decimals)}%`;
}

/**
 * Convert basis points to percentage
 */
export function bpsToPercent(bps: number | bigint): number {
  const num = typeof bps === 'bigint' ? Number(bps) : bps;
  return num / 100;
}

/**
 * Convert percentage to basis points
 */
export function percentToBps(percent: number): number {
  return Math.round(percent * 100);
}

/**
 * Format a timestamp to relative time (e.g., "2 hours ago")
 */
export function formatTimeAgo(timestamp: number | bigint): string {
  const now = Date.now();
  const time = typeof timestamp === 'bigint' ? Number(timestamp) * 1000 : timestamp * 1000;
  const diff = now - time;

  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return 'Just now';
}

/**
 * Validate an Ethereum address
 */
export function isValidAddress(address: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

/**
 * Sleep for a specified duration
 */
export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Clamp a value between min and max
 */
export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
