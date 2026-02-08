'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Percent, TrendingUp, Shield, Clock } from 'lucide-react';

export default function EarnPage() {
  const { isConnected } = useAccount();
  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [activeTab, setActiveTab] = useState<'deposit' | 'withdraw'>('deposit');

  // Mock data
  const stats = {
    totalDeposits: 0,
    totalBorrowed: 0,
    utilization: 0,
    currentAPY: 8.5,
    userDeposit: 0,
    userEarnings: 0,
  };

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh]">
        <h1 className="text-3xl font-bold mb-4">Earn Yield</h1>
        <p className="text-gray-400 mb-8">Deposit USDT to earn yield from leveraged traders</p>
        <ConnectButton />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      <h1 className="text-3xl font-bold mb-8">Lending Pool</h1>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="Total Deposits"
          value={`$${stats.totalDeposits.toLocaleString()}`}
          icon={<Shield className="w-5 h-5 text-primary" />}
        />
        <StatCard
          title="Current APY"
          value={`${stats.currentAPY}%`}
          icon={<Percent className="w-5 h-5 text-green-400" />}
        />
        <StatCard
          title="Utilization Rate"
          value={`${stats.utilization}%`}
          icon={<TrendingUp className="w-5 h-5 text-yellow-400" />}
        />
        <StatCard
          title="Total Borrowed"
          value={`$${stats.totalBorrowed.toLocaleString()}`}
          icon={<Clock className="w-5 h-5 text-purple-400" />}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Deposit/Withdraw Card */}
        <div className="card">
          {/* Tabs */}
          <div className="flex gap-2 mb-6">
            <button
              onClick={() => setActiveTab('deposit')}
              className={`flex-1 py-2 rounded-lg font-medium transition-all ${
                activeTab === 'deposit'
                  ? 'bg-primary text-white'
                  : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
              }`}
            >
              Deposit
            </button>
            <button
              onClick={() => setActiveTab('withdraw')}
              className={`flex-1 py-2 rounded-lg font-medium transition-all ${
                activeTab === 'withdraw'
                  ? 'bg-primary text-white'
                  : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
              }`}
            >
              Withdraw
            </button>
          </div>

          {activeTab === 'deposit' ? (
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Amount to Deposit
                </label>
                <div className="relative">
                  <input
                    type="number"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    placeholder="0.00"
                    className="input w-full text-xl pr-24"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <button className="text-primary text-sm font-medium">MAX</button>
                    <span className="text-gray-500">USDT</span>
                  </div>
                </div>
                <div className="mt-2 text-sm text-gray-500">
                  Balance: 0.00 USDT
                </div>
              </div>

              <div className="bg-dark-300 rounded-lg p-4 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">You will receive</span>
                  <span>{depositAmount || '0'} lvUSDT</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Current APY</span>
                  <span className="text-green-400">{stats.currentAPY}%</span>
                </div>
              </div>

              <button 
                className="btn btn-primary w-full py-3"
                disabled={!depositAmount}
              >
                Deposit USDT
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Amount to Withdraw
                </label>
                <div className="relative">
                  <input
                    type="number"
                    value={withdrawAmount}
                    onChange={(e) => setWithdrawAmount(e.target.value)}
                    placeholder="0.00"
                    className="input w-full text-xl pr-24"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <button className="text-primary text-sm font-medium">MAX</button>
                    <span className="text-gray-500">lvUSDT</span>
                  </div>
                </div>
                <div className="mt-2 text-sm text-gray-500">
                  Deposited: {stats.userDeposit.toFixed(2)} lvUSDT
                </div>
              </div>

              <div className="bg-dark-300 rounded-lg p-4 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">You will receive</span>
                  <span>{withdrawAmount || '0'} USDT</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Available liquidity</span>
                  <span>${(stats.totalDeposits - stats.totalBorrowed).toLocaleString()}</span>
                </div>
              </div>

              <button 
                className="btn btn-secondary w-full py-3"
                disabled={!withdrawAmount}
              >
                Withdraw USDT
              </button>
            </div>
          )}
        </div>

        {/* Your Position */}
        <div className="space-y-6">
          <div className="card">
            <h3 className="font-bold mb-4">Your Position</h3>
            
            <div className="space-y-4">
              <div className="flex justify-between items-center pb-4 border-b border-gray-800">
                <span className="text-gray-400">Deposited</span>
                <div className="text-right">
                  <div className="font-bold">{stats.userDeposit.toFixed(2)} USDT</div>
                  <div className="text-sm text-gray-500">≈ $0.00</div>
                </div>
              </div>

              <div className="flex justify-between items-center pb-4 border-b border-gray-800">
                <span className="text-gray-400">Earnings</span>
                <div className="text-right">
                  <div className="font-bold text-green-400">+{stats.userEarnings.toFixed(2)} USDT</div>
                  <div className="text-sm text-gray-500">All time</div>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-gray-400">Share of Pool</span>
                <span className="font-bold">0%</span>
              </div>
            </div>
          </div>

          {/* How it works */}
          <div className="card bg-primary/5 border-primary/20">
            <h3 className="font-bold mb-4 text-primary">How Lending Works</h3>
            <ul className="space-y-2 text-sm text-gray-400">
              <li className="flex gap-2">
                <span className="text-primary">1.</span>
                Deposit USDT to the lending pool
              </li>
              <li className="flex gap-2">
                <span className="text-primary">2.</span>
                Leveraged traders borrow from the pool
              </li>
              <li className="flex gap-2">
                <span className="text-primary">3.</span>
                Earn interest from borrower fees
              </li>
              <li className="flex gap-2">
                <span className="text-primary">4.</span>
                Withdraw anytime (subject to utilization)
              </li>
            </ul>
          </div>

          {/* APY Chart placeholder */}
          <div className="card">
            <h3 className="font-bold mb-4">APY History</h3>
            <div className="h-32 flex items-center justify-center text-gray-500">
              APY chart coming soon
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon }: {
  title: string;
  value: string;
  icon: React.ReactNode;
}) {
  return (
    <div className="card">
      <div className="flex items-center gap-2 mb-2">
        {icon}
        <span className="text-gray-400 text-sm">{title}</span>
      </div>
      <div className="text-2xl font-bold">{value}</div>
    </div>
  );
}
