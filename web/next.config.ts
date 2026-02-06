import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  basePath: "/web/out",
  // Rewrites work in dev mode only (ignored in static export).
  // Proxies /data/live/* to a file server on port 8080.
  async rewrites() {
    return [
      {
        source: "/data/:path*",
        destination: "http://localhost:8080/data/:path*",
      },
    ];
  },
};

export default nextConfig;
