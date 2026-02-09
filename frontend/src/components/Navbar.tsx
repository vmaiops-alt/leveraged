'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const navItems = [
  { href: '/', label: 'Home' },
  { href: '/trade', label: 'Trade' },
  { href: '/earn', label: 'Earn' },
  { href: '/stake', label: 'Stake' },
];

export function Navbar() {
  const pathname = usePathname();

  return (
    <nav className="border-b border-gray-800 bg-[#181825]/90 backdrop-blur-lg sticky top-0 z-50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center gap-2">
            <span className="text-2xl font-bold bg-gradient-to-r from-indigo-500 to-purple-500 bg-clip-text text-transparent">
              LEVERAGED
            </span>
            <span className="text-xs bg-yellow-500/20 text-yellow-400 px-2 py-0.5 rounded">TESTNET</span>
          </Link>

          <div className="flex items-center gap-1">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={`px-4 py-2 rounded-lg transition-colors ${
                  pathname === item.href
                    ? 'bg-indigo-500/20 text-indigo-400'
                    : 'text-gray-400 hover:text-white hover:bg-gray-800'
                }`}
              >
                {item.label}
              </Link>
            ))}
          </div>
        </div>
      </div>
    </nav>
  );
}
