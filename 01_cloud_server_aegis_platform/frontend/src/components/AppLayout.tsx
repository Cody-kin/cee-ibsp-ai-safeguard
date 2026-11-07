'use client';
import React, { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import Sidebar from './Sidebar';

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [isAuthChecking, setIsAuthChecking] = useState(true);

  const isLoginPage = pathname === '/login';

  useEffect(() => {
    // 每次路由改變時，第一時間檢查 Token
    const token = localStorage.getItem('token');
    
    if (!token && !isLoginPage) {
      // 沒登入，且不是在登入頁 -> 踢回登入頁
      router.replace('/login');
    } else if (token && isLoginPage) {
      // 已經登入，卻跑去登入頁 -> 踢回主畫面
      router.replace('/');
    } else {
      // 權限正常，放行渲染
      setIsAuthChecking(false);
    }
  }, [pathname, router, isLoginPage]);

  // 🌟 1. 檢查期間，顯示純黑背景，絕對不閃爍任何畫面
  if (isAuthChecking) {
    return <div className="min-h-screen bg-[#020617]" />;
  }

  // 🌟 2. 如果是登入頁，只渲染內容，絕對不顯示 Sidebar
  if (isLoginPage) {
    return <>{children}</>;
  }

  // 🌟 3. 正常登入後的系統畫面：左邊 Sidebar，右邊內容
  return (
    <div className="flex min-h-screen bg-[#020617]">
      <Sidebar />
      <main className="flex-1 overflow-x-hidden overflow-y-auto">
        {children}
      </main>
    </div>
  );
}
