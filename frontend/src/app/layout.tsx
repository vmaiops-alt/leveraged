import './globals.css';
import type { Metadata } from 'next';
import { Providers } from '@/components/Providers';
import { Navbar } from '@/components/Navbar';

export const metadata: Metadata = {
  title: 'LEVERAGED - DeFi Leveraged Yield',
  description: 'Earn amplified yields with leveraged positions on BSC',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-dark-300 text-white min-h-screen">
        <Providers>
          <Navbar />
          <main className="container mx-auto px-4 py-8">
            {children}
          </main>
        </Providers>
      </body>
    </html>
  );
}
