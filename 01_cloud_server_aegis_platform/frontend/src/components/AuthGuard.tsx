'use client';
import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('token');
    const isLoginPath = pathname === '/login';

    if (!token && !isLoginPath) {
      router.replace('/login');
    } else if (token && isLoginPath) {
      router.replace('/');
    } else {
      setIsReady(true);
    }
  }, [pathname, router]);

  // 在判定完成前顯示黑畫面，避免閃爍
  if (!isReady) return <div className="min-h-screen bg-[#0B0F19]" />;

  return <>{children}</>;
}
