'use client';

export default function StakePage() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <h1 className="text-3xl font-bold">Stake $LVG</h1>
      
      <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
        <div className="text-center py-12">
          <p className="text-6xl mb-4">🪙</p>
          <h2 className="text-xl font-semibold mb-2">Stake LVG for Rewards</h2>
          <p className="text-gray-400 mb-6">
            Earn protocol revenue share and get fee discounts on trades.
          </p>
          <div className="flex justify-center gap-4">
            <a 
              href="https://testnet.bscscan.com/address/0xBA32bF5e975a53832EB757475B4a620B3219bB01"
              target="_blank"
              className="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 rounded-lg font-medium transition-colors inline-block"
            >
              LVG Token ↗
            </a>
            <a 
              href="https://testnet.bscscan.com/address/0xB837bbcf932D8156B9fe5d06a496e54aF18EBa15"
              target="_blank"
              className="px-6 py-3 bg-gray-700 hover:bg-gray-600 rounded-lg font-medium transition-colors inline-block"
            >
              Staking Contract ↗
            </a>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-2">Total Supply</h3>
          <p className="text-2xl font-bold">100M LVG</p>
        </div>
        <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-2">Fee Discount</h3>
          <p className="text-2xl font-bold text-green-400">Up to 50%</p>
        </div>
        <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-2">Revenue Share</h3>
          <p className="text-2xl font-bold text-purple-400">20%</p>
        </div>
      </div>
    </div>
  );
}
