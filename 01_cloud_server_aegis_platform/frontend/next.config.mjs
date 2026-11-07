/** @type {import('next').NextConfig} */
const nextConfig = {


  // 🌟 限制只用單核編譯，防止記憶體瞬間爆衝
  experimental: {
    cpus: 1,
    workerThreads: false,
  }
};
export default nextConfig;
