'use client';

import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { TrendingUp, Shield, Coins, Zap } from 'lucide-react';
import Link from 'next/link';

export default function Dashboard() {
  const { isConnected } = useAccount();

  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <section className="text-center py-12">
        <h1 className="text-5xl font-bold mb-4">
          <span className="gradient-text">Leveraged</span> Yield Farming
        </h1>
        <p className="text-xl text-gray-400 max-w-2xl mx-auto mb-8">
          Amplify your crypto exposure with up to 5x leverage. 
          Pay only 25% of your gains as fees — keep the rest.
        </p>
        
        {!isConnected ? (
          <div className="flex justify-center">
            <ConnectButton />
          </div>
        ) : (
          <div className="flex justify-center gap-4">
            <Link href="/trade" className="btn btn-primary text-lg px-8 py-3">
              Open Position
            </Link>
            <Link href="/earn" className="btn btn-secondary text-lg px-8 py-3">
              Earn Yield
            </Link>
          </div>
        )}
      </section>

      {/* Stats Cards */}
      <section className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <StatCard
          title="Total Value Locked"
          value="$0"
          change="+0%"
          icon={<Coins className="w-6 h-6 text-primary" />}
        />
        <StatCard
          title="Active Positions"
          value="0"
          change="0"
          icon={<TrendingUp className="w-6 h-6 text-secondary" />}
        />
        <StatCard
          title="$LVG Staked"
          value="0"
          change="0%"
          icon={<Shield className="w-6 h-6 text-yellow-400" />}
        />
        <StatCard
          title="Lending APY"
          value="0%"
          change="-"
          icon={<Zap className="w-6 h-6 text-purple-400" />}
        />
      </section>

      {/* Features */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
        <FeatureCard
          title="Leverage Up to 5x"
          description="Amplify your exposure to BTC, ETH, BNB and more with up to 5x leverage on your positions."
          icon="📈"
        />
        <FeatureCard
          title="25% Value Fee Only"
          description="Revolutionary fee model — you only pay 25% of your value increase, not your yield."
          icon="💰"
        />
        <FeatureCard
          title="Stake $LVG for Benefits"
          description="Stake LVG tokens to reduce fees and earn a share of protocol revenue."
          icon="🎁"
        />
      </section>

      {/* How It Works */}
      <section className="mt-16">
        <h2 className="text-3xl font-bold text-center mb-8">How It Works</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <StepCard 
            step={1} 
            title="Deposit USDT" 
            description="Deposit stablecoins as collateral for your position."
          />
          <StepCard 
            step={2} 
            title="Choose Leverage" 
            description="Select 1x to 5x leverage on your chosen asset."
          />
          <StepCard 
            step={3} 
            title="Earn Exposure" 
            description="Get amplified exposure to asset price movements."
          />
          <StepCard 
            step={4} 
            title="Close & Profit" 
            description="Close your position anytime. Pay 25% fee on value increase only."
          />
        </div>
      </section>
    </div>
  );
}

function StatCard({ title, value, change, icon }: {
  title: string;
  value: string;
  change: string;
  icon: React.ReactNode;
}) {
  return (
    <div className="card">
      <div className="flex items-center justify-between mb-2">
        <span className="text-gray-400 text-sm">{title}</span>
        {icon}
      </div>
      <div className="text-2xl font-bold">{value}</div>
      <div className="text-sm text-gray-500">{change}</div>
    </div>
  );
}

function FeatureCard({ title, description, icon }: {
  title: string;
  description: string;
  icon: string;
}) {
  return (
    <div className="card card-hover">
      <div className="text-4xl mb-4">{icon}</div>
      <h3 className="text-xl font-bold mb-2">{title}</h3>
      <p className="text-gray-400">{description}</p>
    </div>
  );
}

function StepCard({ step, title, description }: {
  step: number;
  title: string;
  description: string;
}) {
  return (
    <div className="card text-center">
      <div className="w-10 h-10 rounded-full bg-primary/20 text-primary font-bold flex items-center justify-center mx-auto mb-4">
        {step}
      </div>
      <h3 className="font-bold mb-2">{title}</h3>
      <p className="text-gray-400 text-sm">{description}</p>
    </div>
  );
}
