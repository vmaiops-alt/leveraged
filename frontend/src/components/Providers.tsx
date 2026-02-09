'use client';

import { ReactNode, useState, useEffect } from 'react';

export function Providers({ children }: { children: ReactNode }) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return (
      <div className="min-h-screen bg-[#11111B] flex items-center justify-center">
        <div className="animate-pulse text-indigo-500 text-xl">Loading LEVERAGED...</div>
      </div>
    );
  }

  return <>{children}</>;
}
