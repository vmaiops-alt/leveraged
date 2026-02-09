'use client';

export default function PositionsPage() {
  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <h1 className="text-3xl font-bold">Your Positions</h1>
      
      <div className="bg-[#181825] border border-gray-800 rounded-xl p-6">
        <div className="text-center py-12">
          <p className="text-6xl mb-4">📊</p>
          <h2 className="text-xl font-semibold mb-2">No Positions Yet</h2>
          <p className="text-gray-400 mb-6">
            Connect your wallet and open a leveraged position to get started.
          </p>
        </div>
      </div>
    </div>
  );
}
