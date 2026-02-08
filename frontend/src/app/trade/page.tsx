'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { ASSETS } from '@/config/wagmi';
import { AlertTriangle, Info, TrendingUp, TrendingDown } from 'lucide-react';

const leverageOptions = [1, 2, 3, 4, 5];

export default function TradePage() {
  const { isConnected, address } = useAccount();
  const [selectedAsset, setSelectedAsset] = useState('WBTC');
  const [amount, setAmount] = useState('');
  const [leverage, setLeverage] = useState(2);

  const asset = ASSETS[selectedAsset as keyof typeof ASSETS];
  const numAmount = parseFloat(amount) || 0;
  const totalExposure = numAmount * leverage;
  const borrowAmount = totalExposure - numAmount;
  const entryFee = numAmount * 0.001; // 0.1%
  
  // Simulated liquidation price (rough estimate)
  const liquidationDrop = (100 / leverage) * 0.85; // ~85% of max drop before liquidation

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh]">
        <h1 className="text-3xl font-bold mb-4">Open a Position</h1>
        <p className="text-gray-400 mb-8">Connect your wallet to start trading</p>
        <ConnectButton />
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-3xl font-bold mb-8">Open Position</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Left: Input Form */}
        <div className="space-y-6">
          {/* Asset Selection */}
          <div className="card">
            <label className="block text-sm text-gray-400 mb-2">Select Asset</label>
            <div className="grid grid-cols-3 gap-2">
              {Object.entries(ASSETS).map(([key, asset]) => (
                <button
                  key={key}
                  onClick={() => setSelectedAsset(key)}
                  className={`p-4 rounded-lg border transition-all ${
                    selectedAsset === key
                      ? 'border-primary bg-primary/10'
                      : 'border-gray-700 hover:border-gray-600'
                  }`}
                >
                  <div className="text-2xl mb-1">{asset.icon}</div>
                  <div className="font-medium">{asset.symbol}</div>
                </button>
              ))}
            </div>
          </div>

          {/* Amount Input */}
          <div className="card">
            <label className="block text-sm text-gray-400 mb-2">Deposit Amount (USDT)</label>
            <div className="relative">
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                className="input w-full text-2xl pr-20"
              />
              <button className="absolute right-3 top-1/2 -translate-y-1/2 text-primary text-sm font-medium">
                MAX
              </button>
            </div>
            <div className="mt-2 text-sm text-gray-500">
              Balance: 0.00 USDT
            </div>
          </div>

          {/* Leverage Slider */}
          <div className="card">
            <div className="flex justify-between items-center mb-4">
              <label className="text-sm text-gray-400">Leverage</label>
              <span className="text-xl font-bold text-primary">{leverage}x</span>
            </div>
            <input
              type="range"
              min="1"
              max="5"
              value={leverage}
              onChange={(e) => setLeverage(parseInt(e.target.value))}
              className="w-full"
            />
            <div className="flex justify-between text-xs text-gray-500 mt-2">
              {leverageOptions.map((l) => (
                <span 
                  key={l} 
                  className={leverage === l ? 'text-primary' : ''}
                >
                  {l}x
                </span>
              ))}
            </div>
          </div>

          {/* Warning for high leverage */}
          {leverage >= 4 && (
            <div className="bg-yellow-500/10 border border-yellow-500/50 rounded-lg p-4 flex gap-3">
              <AlertTriangle className="w-5 h-5 text-yellow-500 shrink-0" />
              <div className="text-sm">
                <p className="font-medium text-yellow-500">High Leverage Warning</p>
                <p className="text-gray-400">
                  {leverage}x leverage significantly increases liquidation risk. 
                  A {liquidationDrop.toFixed(0)}% price drop will liquidate your position.
                </p>
              </div>
            </div>
          )}

          {/* Open Position Button */}
          <button 
            className="btn btn-primary w-full py-4 text-lg"
            disabled={!amount || numAmount <= 0}
          >
            Open {leverage}x {asset.symbol} Position
          </button>
        </div>

        {/* Right: Position Summary */}
        <div className="space-y-6">
          <div className="card">
            <h3 className="font-bold mb-4">Position Summary</h3>
            
            <div className="space-y-3">
              <SummaryRow label="Deposit" value={`${numAmount.toFixed(2)} USDT`} />
              <SummaryRow label="Entry Fee (0.1%)" value={`-${entryFee.toFixed(2)} USDT`} />
              <SummaryRow label="Net Deposit" value={`${(numAmount - entryFee).toFixed(2)} USDT`} />
              <div className="border-t border-gray-700 my-2" />
              <SummaryRow label="Leverage" value={`${leverage}x`} highlight />
              <SummaryRow label="Total Exposure" value={`${totalExposure.toFixed(2)} USDT`} highlight />
              <SummaryRow label="Borrowed Amount" value={`${borrowAmount.toFixed(2)} USDT`} />
            </div>
          </div>

          <div className="card">
            <h3 className="font-bold mb-4">Risk Metrics</h3>
            
            <div className="space-y-4">
              <div>
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-gray-400">Health Factor</span>
                  <span className="health-safe font-medium">∞</span>
                </div>
                <div className="h-2 bg-gray-700 rounded-full">
                  <div className="h-full bg-green-500 rounded-full" style={{ width: '100%' }} />
                </div>
              </div>

              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Liquidation Price Drop</span>
                <span className="text-red-400">-{liquidationDrop.toFixed(1)}%</span>
              </div>

              <div className="flex justify-between text-sm">
                <span className="text-gray-400">Borrow APR</span>
                <span>~5-15%</span>
              </div>
            </div>
          </div>

          <div className="card bg-primary/5 border-primary/20">
            <div className="flex gap-3">
              <Info className="w-5 h-5 text-primary shrink-0" />
              <div className="text-sm">
                <p className="font-medium text-primary">Fee Structure</p>
                <p className="text-gray-400 mt-1">
                  You only pay <span className="text-white">25%</span> of your value increase when closing. 
                  No fees if your position is at a loss.
                </p>
              </div>
            </div>
          </div>

          {/* P&L Scenarios */}
          <div className="card">
            <h3 className="font-bold mb-4">P&L Scenarios</h3>
            <div className="space-y-2 text-sm">
              <ScenarioRow 
                change={20} 
                leverage={leverage} 
                deposit={numAmount - entryFee} 
              />
              <ScenarioRow 
                change={10} 
                leverage={leverage} 
                deposit={numAmount - entryFee} 
              />
              <ScenarioRow 
                change={-10} 
                leverage={leverage} 
                deposit={numAmount - entryFee} 
              />
              <ScenarioRow 
                change={-20} 
                leverage={leverage} 
                deposit={numAmount - entryFee} 
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function SummaryRow({ label, value, highlight }: {
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div className="flex justify-between">
      <span className="text-gray-400">{label}</span>
      <span className={highlight ? 'font-bold text-primary' : ''}>{value}</span>
    </div>
  );
}

function ScenarioRow({ change, leverage, deposit }: {
  change: number;
  leverage: number;
  deposit: number;
}) {
  const leveragedChange = change * leverage;
  const valueChange = deposit * (leveragedChange / 100);
  const fee = valueChange > 0 ? valueChange * 0.25 : 0;
  const netPnL = valueChange - fee;
  const pnlPercent = deposit > 0 ? (netPnL / deposit) * 100 : 0;
  
  const isPositive = netPnL >= 0;
  
  return (
    <div className="flex justify-between items-center py-2 border-b border-gray-800 last:border-0">
      <div className="flex items-center gap-2">
        {isPositive ? (
          <TrendingUp className="w-4 h-4 text-green-400" />
        ) : (
          <TrendingDown className="w-4 h-4 text-red-400" />
        )}
        <span className="text-gray-400">Price {change > 0 ? '+' : ''}{change}%</span>
      </div>
      <div className={isPositive ? 'text-green-400' : 'text-red-400'}>
        {netPnL >= 0 ? '+' : ''}{netPnL.toFixed(2)} USDT ({pnlPercent.toFixed(1)}%)
      </div>
    </div>
  );
}
