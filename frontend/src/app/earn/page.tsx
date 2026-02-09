'use client';

export default function EarnPage() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <h1 className="text-3xl font-bold">Earn Yield</h1>
      
      <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
        <div className="text-center py-12">
          <p className="text-6xl mb-4">💰</p>
          <h2 className="text-xl font-semibold mb-2">Lend USDT, Earn Interest</h2>
          <p className="text-gray-400 mb-6">
            Deposit USDT into the lending pool. Earn interest from leveraged traders.
          </p>
          <a 
            href="https://testnet.bscscan.com/address/0xCE066289D798300ceFCC1B6FdEa5dD10AF113486"
            target="_blank"
            className="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 rounded-lg font-medium transition-colors inline-block"
          >
            View Lending Pool ↗
          </a>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-2">Current APY</h3>
          <p className="text-3xl font-bold text-green-400">~8-15%</p>
          <p className="text-gray-400 text-sm mt-2">Variable based on utilization</p>
        </div>
        <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-2">Total Deposits</h3>
          <p className="text-3xl font-bold">$0</p>
          <p className="text-gray-400 text-sm mt-2">Be the first lender!</p>
        </div>
      </div>
    </div>
  );
}
