'use client';

import Link from 'next/link';

export default function Dashboard() {
  return (
    <div className="space-y-8">
      {/* Hero Section */}
      <section className="text-center py-12">
        <h1 className="text-5xl font-bold mb-4">
          <span className="bg-gradient-to-r from-indigo-500 to-purple-500 bg-clip-text text-transparent">
            LEVERAGED
          </span>
        </h1>
        <p className="text-xl text-gray-400 max-w-2xl mx-auto mb-8">
          Amplify your crypto exposure with up to 5x leverage. 
          Pay only 25% of your gains as fees — keep the rest.
        </p>
        
        <div className="flex justify-center gap-4">
          <Link 
            href="/trade" 
            className="px-8 py-3 bg-indigo-600 hover:bg-indigo-700 rounded-lg font-medium transition-colors"
          >
            Launch App
          </Link>
          <a 
            href="https://vmaiops-alt.github.io/leveraged/"
            target="_blank"
            className="px-8 py-3 bg-gray-700 hover:bg-gray-600 rounded-lg font-medium transition-colors"
          >
            Read Docs
          </a>
        </div>
      </section>

      {/* Deployed Contracts */}
      <section className="bg-[#181825] border border-gray-800 rounded-xl p-6">
        <h2 className="text-xl font-bold mb-4 text-green-400">✅ Deployed on BSC Testnet</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm font-mono">
          <ContractLink name="LeveragedVault" address="0xE163112607794a73281Cb390ae9FC30f3287A7D8" />
          <ContractLink name="LendingPool" address="0xCE066289D798300ceFCC1B6FdEa5dD10AF113486" />
          <ContractLink name="LVGToken" address="0xBA32bF5e975a53832EB757475B4a620B3219bB01" />
          <ContractLink name="LVGStaking" address="0xB837bbcf932D8156B9fe5d06a496e54aF18EBa15" />
          <ContractLink name="PriceOracle" address="0x8094813806b30dC45259Fc8fdf01FFb85dDB81Ee" />
          <ContractLink name="FeeCollector" address="0x77D8AfD4dB7a29c26d297E021C9C24E9187B6f77" />
          <ContractLink name="Liquidator" address="0xc3C7265C547e9a4040A671E6561f4a2f3dE99c87" />
          <ContractLink name="ValueTracker" address="0xC080c0F2a33cDa382fcF3064fA9232Cf09273511" />
        </div>
      </section>

      {/* Features */}
      <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <FeatureCard 
          title="Up to 5x Leverage"
          description="Amplify your exposure to BTC, ETH, and BNB with up to 5x leverage."
          icon="📈"
        />
        <FeatureCard 
          title="25% Value Fee Only"
          description="Only pay fees on your gains. No fees if price goes down."
          icon="💰"
        />
        <FeatureCard 
          title="Earn with $LVG"
          description="Stake LVG tokens for fee discounts and protocol revenue share."
          icon="🪙"
        />
      </section>

      {/* Testnet Banner */}
      <section className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 text-center">
        <p className="text-yellow-400">
          🚧 <strong>BSC Testnet</strong> — Contracts deployed! Frontend Web3 integration coming soon.
        </p>
      </section>
    </div>
  );
}

function ContractLink({ name, address }: { name: string; address: string }) {
  return (
    <div className="flex justify-between items-center p-2 bg-[#11111B] rounded">
      <span className="text-gray-400">{name}</span>
      <a 
        href={`https://testnet.bscscan.com/address/${address}`}
        target="_blank"
        className="text-indigo-400 hover:text-indigo-300"
      >
        {address.slice(0, 6)}...{address.slice(-4)} ↗
      </a>
    </div>
  );
}

function FeatureCard({ title, description, icon }: { title: string; description: string; icon: string }) {
  return (
    <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
      <div className="text-3xl mb-3">{icon}</div>
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-gray-400">{description}</p>
    </div>
  );
}
