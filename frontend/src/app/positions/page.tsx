'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { ASSETS } from '@/config/wagmi';
import { TrendingUp, TrendingDown, AlertTriangle, Plus, X } from 'lucide-react';
import Link from 'next/link';

// Mock positions for demo
const mockPositions = [
  {
    id: 0,
    asset: 'WBTC',
    depositAmount: 1000,
    leverage: 3,
    totalExposure: 3000,
    entryPrice: 45000,
    currentPrice: 48500,
    healthFactor: 2.45,
    pnl: 233.33,
    pnlPercent: 23.33,
    isActive: true,
  },
  {
    id: 1,
    asset: 'WETH',
    depositAmount: 500,
    leverage: 2,
    totalExposure: 1000,
    entryPrice: 2500,
    currentPrice: 2400,
    healthFactor: 1.85,
    pnl: -40,
    pnlPercent: -8,
    isActive: true,
  },
];

export default function PositionsPage() {
  const { isConnected } = useAccount();
  const [selectedPosition, setSelectedPosition] = useState<number | null>(null);

  // For demo, show empty state or mock data
  const positions = isConnected ? [] : []; // Use mockPositions for demo

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh]">
        <h1 className="text-3xl font-bold mb-4">Your Positions</h1>
        <p className="text-gray-400 mb-8">Connect your wallet to view your positions</p>
        <ConnectButton />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Your Positions</h1>
        <Link href="/trade" className="btn btn-primary flex items-center gap-2">
          <Plus className="w-4 h-4" />
          New Position
        </Link>
      </div>

      {positions.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="space-y-4">
          {/* Summary Stats */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <SummaryCard 
              title="Total Exposure" 
              value="$0" 
            />
            <SummaryCard 
              title="Total P&L" 
              value="$0" 
              isProfit={true}
            />
            <SummaryCard 
              title="Avg Health Factor" 
              value="∞" 
            />
            <SummaryCard 
              title="Active Positions" 
              value="0" 
            />
          </div>

          {/* Position Cards */}
          <div className="space-y-4">
            {positions.map((position) => (
              <PositionCard 
                key={position.id} 
                position={position}
                onSelect={() => setSelectedPosition(position.id)}
              />
            ))}
          </div>
        </div>
      )}

      {/* Position Detail Modal */}
      {selectedPosition !== null && (
        <PositionModal 
          position={positions.find(p => p.id === selectedPosition)!}
          onClose={() => setSelectedPosition(null)}
        />
      )}
    </div>
  );
}

function EmptyState() {
  return (
    <div className="card text-center py-16">
      <div className="text-6xl mb-4">📊</div>
      <h2 className="text-2xl font-bold mb-2">No Open Positions</h2>
      <p className="text-gray-400 mb-6">
        Open your first leveraged position to start trading
      </p>
      <Link href="/trade" className="btn btn-primary inline-flex items-center gap-2">
        <Plus className="w-4 h-4" />
        Open Position
      </Link>
    </div>
  );
}

function SummaryCard({ title, value, isProfit }: {
  title: string;
  value: string;
  isProfit?: boolean;
}) {
  return (
    <div className="card">
      <div className="text-sm text-gray-400 mb-1">{title}</div>
      <div className={`text-2xl font-bold ${
        isProfit !== undefined 
          ? isProfit ? 'text-green-400' : 'text-red-400'
          : ''
      }`}>
        {value}
      </div>
    </div>
  );
}

function PositionCard({ position, onSelect }: {
  position: typeof mockPositions[0];
  onSelect: () => void;
}) {
  const asset = ASSETS[position.asset as keyof typeof ASSETS];
  const isProfit = position.pnl >= 0;
  const isHealthy = position.healthFactor > 1.5;
  const isWarning = position.healthFactor > 1.1 && position.healthFactor <= 1.5;

  return (
    <div 
      className="card card-hover cursor-pointer"
      onClick={onSelect}
    >
      <div className="flex items-center justify-between">
        {/* Left: Asset Info */}
        <div className="flex items-center gap-4">
          <div className="text-3xl">{asset?.icon || '?'}</div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-bold text-lg">{asset?.symbol || position.asset}</span>
              <span className="px-2 py-0.5 bg-primary/20 text-primary rounded text-sm">
                {position.leverage}x
              </span>
            </div>
            <div className="text-sm text-gray-400">
              ${position.totalExposure.toLocaleString()} exposure
            </div>
          </div>
        </div>

        {/* Center: P&L */}
        <div className="text-center">
          <div className={`flex items-center gap-1 justify-center ${
            isProfit ? 'text-green-400' : 'text-red-400'
          }`}>
            {isProfit ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
            <span className="font-bold">
              {isProfit ? '+' : ''}{position.pnl.toFixed(2)} USDT
            </span>
          </div>
          <div className={`text-sm ${isProfit ? 'text-green-400/70' : 'text-red-400/70'}`}>
            {isProfit ? '+' : ''}{position.pnlPercent.toFixed(2)}%
          </div>
        </div>

        {/* Right: Health Factor */}
        <div className="text-right">
          <div className="flex items-center gap-2 justify-end">
            {!isHealthy && <AlertTriangle className={`w-4 h-4 ${isWarning ? 'text-yellow-400' : 'text-red-400'}`} />}
            <span className={`font-bold ${
              isHealthy ? 'text-green-400' : isWarning ? 'text-yellow-400' : 'text-red-400'
            }`}>
              {position.healthFactor.toFixed(2)}
            </span>
          </div>
          <div className="text-sm text-gray-400">Health Factor</div>
        </div>
      </div>

      {/* Bottom: Entry/Current Price */}
      <div className="flex justify-between mt-4 pt-4 border-t border-gray-800 text-sm">
        <div>
          <span className="text-gray-400">Entry:</span>{' '}
          <span>${position.entryPrice.toLocaleString()}</span>
        </div>
        <div>
          <span className="text-gray-400">Current:</span>{' '}
          <span>${position.currentPrice.toLocaleString()}</span>
        </div>
        <div>
          <span className="text-gray-400">Deposit:</span>{' '}
          <span>${position.depositAmount.toLocaleString()}</span>
        </div>
      </div>
    </div>
  );
}

function PositionModal({ position, onClose }: {
  position: typeof mockPositions[0];
  onClose: () => void;
}) {
  const [addCollateralAmount, setAddCollateralAmount] = useState('');
  const asset = ASSETS[position.asset as keyof typeof ASSETS];
  const isProfit = position.pnl >= 0;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="card max-w-lg w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <span className="text-3xl">{asset?.icon}</span>
            <div>
              <h2 className="text-xl font-bold">{asset?.symbol} Position</h2>
              <span className="text-sm text-gray-400">#{position.id}</span>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-gray-800 rounded-lg">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 gap-4 mb-6">
          <StatRow label="Leverage" value={`${position.leverage}x`} />
          <StatRow label="Total Exposure" value={`$${position.totalExposure.toLocaleString()}`} />
          <StatRow label="Deposit" value={`$${position.depositAmount.toLocaleString()}`} />
          <StatRow label="Borrowed" value={`$${(position.totalExposure - position.depositAmount).toLocaleString()}`} />
          <StatRow label="Entry Price" value={`$${position.entryPrice.toLocaleString()}`} />
          <StatRow label="Current Price" value={`$${position.currentPrice.toLocaleString()}`} />
          <StatRow 
            label="P&L" 
            value={`${isProfit ? '+' : ''}$${position.pnl.toFixed(2)} (${position.pnlPercent.toFixed(2)}%)`}
            valueClass={isProfit ? 'text-green-400' : 'text-red-400'}
          />
          <StatRow 
            label="Health Factor" 
            value={position.healthFactor.toFixed(2)}
            valueClass={position.healthFactor > 1.5 ? 'text-green-400' : position.healthFactor > 1.1 ? 'text-yellow-400' : 'text-red-400'}
          />
        </div>

        {/* Add Collateral */}
        <div className="mb-6">
          <label className="block text-sm text-gray-400 mb-2">Add Collateral</label>
          <div className="flex gap-2">
            <input
              type="number"
              value={addCollateralAmount}
              onChange={(e) => setAddCollateralAmount(e.target.value)}
              placeholder="0.00"
              className="input flex-1"
            />
            <button className="btn btn-secondary" disabled={!addCollateralAmount}>
              Add
            </button>
          </div>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <button className="btn btn-danger flex-1">
            Close Position
          </button>
        </div>

        {/* Fee info */}
        {isProfit && (
          <div className="mt-4 p-3 bg-primary/10 rounded-lg text-sm">
            <p className="text-gray-400">
              Closing fee: <span className="text-white">${(position.pnl * 0.25).toFixed(2)} USDT</span>
              <span className="text-gray-500"> (25% of profit)</span>
            </p>
            <p className="text-gray-400">
              You receive: <span className="text-green-400">${(position.depositAmount + position.pnl * 0.75).toFixed(2)} USDT</span>
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

function StatRow({ label, value, valueClass }: {
  label: string;
  value: string;
  valueClass?: string;
}) {
  return (
    <div className="flex justify-between">
      <span className="text-gray-400">{label}</span>
      <span className={valueClass || 'font-medium'}>{value}</span>
    </div>
  );
}
