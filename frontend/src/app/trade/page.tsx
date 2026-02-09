'use client';

export default function TradePage() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <h1 className="text-3xl font-bold">Open Leveraged Position</h1>
      
      <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
        <div className="text-center py-12">
          <p className="text-6xl mb-4">🔗</p>
          <h2 className="text-xl font-semibold mb-2">Connect Wallet to Trade</h2>
          <p className="text-gray-400 mb-6">
            Web3 integration coming soon. Contracts are deployed and ready!
          </p>
          <a 
            href="https://testnet.bscscan.com/address/0xE163112607794a73281Cb390ae9FC30f3287A7D8"
            target="_blank"
            className="px-6 py-3 bg-indigo-600 hover:bg-indigo-700 rounded-lg font-medium transition-colors inline-block"
          >
            View Vault Contract ↗
          </a>
        </div>
      </div>

      {/* How it works */}
      <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
        <h2 className="text-xl font-semibold mb-4">How Leveraged Trading Works</h2>
        <div className="space-y-4 text-gray-400">
          <p>1. <strong className="text-white">Deposit USDT</strong> as collateral</p>
          <p>2. <strong className="text-white">Choose leverage</strong> (1x - 5x)</p>
          <p>3. <strong className="text-white">Select asset</strong> (BTC, ETH, or BNB)</p>
          <p>4. <strong className="text-white">Open position</strong> - your exposure is amplified</p>
          <p>5. <strong className="text-white">Close anytime</strong> - pay 25% fee only on gains</p>
        </div>
      </div>
    </div>
  );
}
