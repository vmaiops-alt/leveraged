'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Gift, Lock, Percent, Coins } from 'lucide-react';

export default function StakePage() {
  const { isConnected } = useAccount();
  const [stakeAmount, setStakeAmount] = useState('');
  const [unstakeAmount, setUnstakeAmount] = useState('');
  const [activeTab, setActiveTab] = useState<'stake' | 'unstake'>('stake');

  // Mock data
  const stats = {
    totalStaked: 0,
    stakingAPR: 25.5,
    userStaked: 0,
    userRewards: 0,
    feeDiscount: 0,
    lvgBalance: 0,
    lvgPrice: 0.05,
  };

  // Fee discount tiers
  const discountTiers = [
    { staked: 1000, discount: 5 },
    { staked: 5000, discount: 10 },
    { staked: 25000, discount: 15 },
    { staked: 100000, discount: 20 },
    { staked: 500000, discount: 25 },
  ];

  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh]">
        <h1 className="text-3xl font-bold mb-4">Stake $LVG</h1>
        <p className="text-gray-400 mb-8">Stake LVG tokens to reduce fees and earn rewards</p>
        <ConnectButton />
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto">
      <h1 className="text-3xl font-bold mb-8">$LVG Staking</h1>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="Total Staked"
          value={`${(stats.totalStaked / 1000000).toFixed(2)}M LVG`}
          subvalue={`$${(stats.totalStaked * stats.lvgPrice).toLocaleString()}`}
          icon={<Lock className="w-5 h-5 text-primary" />}
        />
        <StatCard
          title="Staking APR"
          value={`${stats.stakingAPR}%`}
          subvalue="Paid in USDT"
          icon={<Percent className="w-5 h-5 text-green-400" />}
        />
        <StatCard
          title="Your Fee Discount"
          value={`${stats.feeDiscount}%`}
          subvalue="On 25% value fee"
          icon={<Gift className="w-5 h-5 text-yellow-400" />}
        />
        <StatCard
          title="LVG Price"
          value={`$${stats.lvgPrice.toFixed(4)}`}
          subvalue="USDT"
          icon={<Coins className="w-5 h-5 text-purple-400" />}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Stake/Unstake Card */}
        <div className="card">
          {/* Tabs */}
          <div className="flex gap-2 mb-6">
            <button
              onClick={() => setActiveTab('stake')}
              className={`flex-1 py-2 rounded-lg font-medium transition-all ${
                activeTab === 'stake'
                  ? 'bg-primary text-white'
                  : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
              }`}
            >
              Stake
            </button>
            <button
              onClick={() => setActiveTab('unstake')}
              className={`flex-1 py-2 rounded-lg font-medium transition-all ${
                activeTab === 'unstake'
                  ? 'bg-primary text-white'
                  : 'bg-gray-800 text-gray-400 hover:bg-gray-700'
              }`}
            >
              Unstake
            </button>
          </div>

          {activeTab === 'stake' ? (
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Amount to Stake
                </label>
                <div className="relative">
                  <input
                    type="number"
                    value={stakeAmount}
                    onChange={(e) => setStakeAmount(e.target.value)}
                    placeholder="0.00"
                    className="input w-full text-xl pr-24"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <button className="text-primary text-sm font-medium">MAX</button>
                    <span className="text-gray-500">LVG</span>
                  </div>
                </div>
                <div className="mt-2 text-sm text-gray-500">
                  Balance: {stats.lvgBalance.toLocaleString()} LVG
                </div>
              </div>

              <div className="bg-dark-300 rounded-lg p-4 space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Value</span>
                  <span>${((parseFloat(stakeAmount) || 0) * stats.lvgPrice).toFixed(2)}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-400">Expected APR</span>
                  <span className="text-green-400">{stats.stakingAPR}%</span>
                </div>
              </div>

              <button 
                className="btn btn-primary w-full py-3"
                disabled={!stakeAmount}
              >
                Stake LVG
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Amount to Unstake
                </label>
                <div className="relative">
                  <input
                    type="number"
                    value={unstakeAmount}
                    onChange={(e) => setUnstakeAmount(e.target.value)}
                    placeholder="0.00"
                    className="input w-full text-xl pr-24"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <button className="text-primary text-sm font-medium">MAX</button>
                    <span className="text-gray-500">LVG</span>
                  </div>
                </div>
                <div className="mt-2 text-sm text-gray-500">
                  Staked: {stats.userStaked.toLocaleString()} LVG
                </div>
              </div>

              <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 text-sm">
                <p className="text-yellow-500">
                  ⚠️ Unstaking will reduce your fee discount tier
                </p>
              </div>

              <button 
                className="btn btn-secondary w-full py-3"
                disabled={!unstakeAmount}
              >
                Unstake LVG
              </button>
            </div>
          )}
        </div>

        {/* Right Column */}
        <div className="space-y-6">
          {/* Your Position */}
          <div className="card">
            <h3 className="font-bold mb-4">Your Staking Position</h3>
            
            <div className="space-y-4">
              <div className="flex justify-between items-center pb-4 border-b border-gray-800">
                <span className="text-gray-400">Staked</span>
                <div className="text-right">
                  <div className="font-bold">{stats.userStaked.toLocaleString()} LVG</div>
                  <div className="text-sm text-gray-500">
                    ≈ ${(stats.userStaked * stats.lvgPrice).toFixed(2)}
                  </div>
                </div>
              </div>

              <div className="flex justify-between items-center pb-4 border-b border-gray-800">
                <span className="text-gray-400">Pending Rewards</span>
                <div className="text-right">
                  <div className="font-bold text-green-400">
                    {stats.userRewards.toFixed(2)} USDT
                  </div>
                  <button className="text-sm text-primary">Claim</button>
                </div>
              </div>

              <div className="flex justify-between items-center">
                <span className="text-gray-400">Fee Discount</span>
                <span className="font-bold text-yellow-400">{stats.feeDiscount}% off</span>
              </div>
            </div>
          </div>

          {/* Fee Discount Tiers */}
          <div className="card">
            <h3 className="font-bold mb-4">Fee Discount Tiers</h3>
            <div className="space-y-2">
              {discountTiers.map((tier, i) => {
                const isActive = stats.userStaked >= tier.staked;
                const isNext = !isActive && (i === 0 || stats.userStaked >= discountTiers[i - 1].staked);
                
                return (
                  <div 
                    key={tier.staked}
                    className={`flex justify-between items-center p-3 rounded-lg ${
                      isActive 
                        ? 'bg-primary/20 border border-primary/50' 
                        : isNext
                          ? 'bg-yellow-500/10 border border-yellow-500/30'
                          : 'bg-dark-300'
                    }`}
                  >
                    <div>
                      <span className="font-medium">
                        {tier.staked >= 1000 
                          ? `${(tier.staked / 1000).toFixed(0)}K` 
                          : tier.staked} LVG
                      </span>
                      {isNext && (
                        <span className="text-xs text-yellow-500 ml-2">Next tier</span>
                      )}
                    </div>
                    <span className={`font-bold ${isActive ? 'text-primary' : 'text-gray-500'}`}>
                      {tier.discount}% off
                    </span>
                  </div>
                );
              })}
            </div>
            <p className="text-xs text-gray-500 mt-4">
              Discount applies to the 25% value increase fee
            </p>
          </div>

          {/* Benefits */}
          <div className="card bg-primary/5 border-primary/20">
            <h3 className="font-bold mb-4 text-primary">Staking Benefits</h3>
            <ul className="space-y-2 text-sm text-gray-400">
              <li className="flex gap-2">
                <span className="text-green-400">✓</span>
                Earn share of protocol fees in USDT
              </li>
              <li className="flex gap-2">
                <span className="text-green-400">✓</span>
                Up to 25% discount on value increase fee
              </li>
              <li className="flex gap-2">
                <span className="text-green-400">✓</span>
                No lockup period — unstake anytime
              </li>
              <li className="flex gap-2">
                <span className="text-green-400">✓</span>
                Governance voting rights (coming soon)
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ title, value, subvalue, icon }: {
  title: string;
  value: string;
  subvalue?: string;
  icon: React.ReactNode;
}) {
  return (
    <div className="card">
      <div className="flex items-center gap-2 mb-2">
        {icon}
        <span className="text-gray-400 text-sm">{title}</span>
      </div>
      <div className="text-2xl font-bold">{value}</div>
      {subvalue && <div className="text-sm text-gray-500">{subvalue}</div>}
    </div>
  );
}
