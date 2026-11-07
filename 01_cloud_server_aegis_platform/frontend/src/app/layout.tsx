'use client';
import './globals.css';
import { Inter } from 'next/font/google';
import { Toaster } from 'react-hot-toast';
import { usePathname } from 'next/navigation';
import Sidebar from '@/components/Sidebar';
import AuthGuard from '@/components/AuthGuard';

const inter = Inter({ subsets: ['latin'] });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isLoginPage = pathname === '/login';

  return (
    <html lang="en">
      <body className={`${inter.className} bg-[#0B0F19] text-white antialiased`}>
        <AuthGuard>
          {/* 🌟 核心修復：使用 h-screen 鎖定螢幕高度，防止滾動條重疊 */}
          <div className="flex h-screen w-full overflow-hidden">
            
            {!isLoginPage && <Sidebar />}
            
            {/* 🌟 核心修復 2：加上 min-w-0，這是 Flexbox 防止被內部元素(如表格)撐破的終極大絕招 */}
            {/* 加入 pt-16 是為了在手機版時，不要讓頂部的漢堡導航列遮住內容 */}
            <main className={`flex-1 min-w-0 h-full overflow-y-auto overflow-x-hidden relative ${!isLoginPage ? 'pt-16 md:pt-0' : ''}`}>
              
              {/* 讓內部超寬的內容 (如 Events Table) 能夠自由水平滑動，而不影響整體版面 */}
              <div className="w-full max-w-full overflow-x-auto">
                {children}
              </div>

            </main>

          </div>
          <Toaster position="top-right" />
        </AuthGuard>
      </body>
    </html>
  );
}
