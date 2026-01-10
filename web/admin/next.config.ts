import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://localhost:8080/api/:path*', // Proxy to Go Backend
      },
      {
        source: '/sub',
        destination: 'http://localhost:8080/sub',
      },
    ]
  },
};

export default nextConfig;
