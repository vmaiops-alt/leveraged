/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  webpack: (config, { isServer }) => {
    // Fix for WalletConnect and other web3 libraries
    config.resolve.fallback = { 
      fs: false, 
      net: false, 
      tls: false,
      encoding: false,
    };
    
    // Handle problematic modules
    config.resolve.alias = {
      ...config.resolve.alias,
      'pino-pretty': false,
      'lokijs': false,
      'encoding': false,
      '@react-native-async-storage/async-storage': false,
    };
    
    // Externalize problematic packages
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        crypto: false,
        stream: false,
        http: false,
        https: false,
        zlib: false,
      };
    }
    
    return config;
  },
}

module.exports = nextConfig
