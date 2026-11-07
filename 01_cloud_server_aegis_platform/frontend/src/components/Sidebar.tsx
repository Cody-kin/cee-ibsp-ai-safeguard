'use client';
import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { LayoutDashboard, Cpu, AlertTriangle, Activity, Settings, Shield, LogOut, Languages, Menu, X , CloudUpload } from 'lucide-react';
import { useLangStore } from '@/store/langStore';
import toast from 'react-hot-toast';

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { lang, toggleLang, t } = useLangStore();
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => setIsOpen(false), [pathname]);

  const handleLogout = () => {
    localStorage.removeItem('token');
    toast.success(lang === 'en' ? 'Logged out successfully' : '已安全登出', {
      style: { background: '#172033', color: '#fff', border: '1px solid #2A3750' }
    });
    router.replace('/login');
  };

  return (
    <>
      <div className="md:hidden fixed top-0 left-0 w-full h-16 bg-[#0B0F19]/90 backdrop-blur-md border-b border-[#1E293B] z-40 flex items-center justify-between px-5">
        <div className="flex items-center gap-2">
          <Shield className="w-6 h-6 text-indigo-400" />
          <span className="text-lg font-black text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-emerald-400">
            AI-SafeGuard
          </span>
        </div>
        <button onClick={() => setIsOpen(true)} className="p-2 text-gray-400 hover:text-white transition-colors">
          <Menu className="w-6 h-6" />
        </button>
      </div>

      {isOpen && <div className="md:hidden fixed inset-0 bg-black/60 backdrop-blur-sm z-40 transition-opacity" onClick={() => setIsOpen(false)} />}

      {/* 🌟 核心修復：加上 flex-shrink-0，確保導航欄絕對不會被右邊的寬表格擠壓變形 */}
      <aside className={`flex-shrink-0 fixed inset-y-0 left-0 z-50 w-64 bg-[#0B0F19] border-r border-[#1E293B] flex flex-col h-screen transform transition-transform duration-300 ease-in-out md:relative md:translate-x-0 ${isOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        
        <div className="p-6 flex items-center justify-between gap-3 mb-2 mt-2">
          <div className="flex items-center gap-3">
            <div className="bg-[#172033] p-2.5 rounded-xl border border-[#2A3750] shadow-lg">
              <Shield className="w-5 h-5 text-indigo-400" />
            </div>
            <span className="text-xl font-black text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-emerald-400 tracking-wide">
              AI-SafeGuard
            </span>
          </div>
          <button onClick={() => setIsOpen(false)} className="md:hidden p-1 text-gray-400 hover:text-white rounded-lg hover:bg-[#1E293B] transition-colors">
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto custom-scrollbar">
          <div className="mb-8 mt-2">
            <h3 className="px-7 text-[11px] font-bold text-gray-500 uppercase tracking-widest mb-3">{t('menuOverview')}</h3>
            <nav className="space-y-1 px-4">
              <NavItem href="/" icon={LayoutDashboard} label={t('menuDashboard')} active={pathname === '/'} />
              <NavItem href="/devices" icon={Cpu} label={t('menuDevices')} active={pathname === '/devices'} />
              <NavItem href="/ota" icon={CloudUpload} label={lang === 'en' ? 'OTA Updates' : 'OTA 升級'} active={pathname === '/ota'} />
              <NavItem href="/events" icon={AlertTriangle} label={t('menuEvents')} active={pathname === '/events'} />
            </nav>
          </div>

          <div className="mb-8">
            <h3 className="px-7 text-[11px] font-bold text-gray-500 uppercase tracking-widest mb-3">{t('menuAnalytics')}</h3>
            <nav className="space-y-1 px-4">
              <NavItem href="/analytics" icon={Activity} label={t('menuSensor')} active={pathname === '/analytics'} />
            </nav>
          </div>

          <div className="mb-8">
            <h3 className="px-7 text-[11px] font-bold text-gray-500 uppercase tracking-widest mb-3">{t('menuConfig')}</h3>
            <nav className="space-y-1 px-4">
              <NavItem href="/settings" icon={Settings} label={t('menuSettings')} active={pathname === '/settings'} />
            </nav>
          </div>
        </div>

        <div className="p-4 border-t border-[#1E293B] space-y-2 bg-[#0B0F19]">
          <button onClick={toggleLang} className="w-full flex items-center gap-3 px-3 py-3 text-gray-400 hover:text-gray-200 hover:bg-[#131B2C] rounded-xl transition-colors outline-none">
            <Languages className="w-4 h-4" />
            <span className="text-sm font-medium">{lang === 'en' ? '切換至繁體中文' : 'Switch to English'}</span>
          </button>
          <button onClick={handleLogout} className="w-full flex items-center gap-3 px-3 py-3 text-[#fca5a5] hover:bg-red-500/10 hover:text-red-400 rounded-xl transition-colors outline-none">
            <LogOut className="w-4 h-4" />
            <span className="text-sm font-medium">{t('btnLogout')}</span>
          </button>
        </div>
      </aside>
    </>
  );
}

function NavItem({ href, icon: Icon, label, active }: { href: string, icon: any, label: string, active: boolean }) {
  return (
    <Link href={href} className={`flex items-center gap-3 px-3 py-3 rounded-xl transition-all ${active ? 'bg-[#172033] text-indigo-400 font-semibold shadow-sm' : 'text-gray-400 hover:bg-[#131B2C] hover:text-gray-200 font-medium'}`}>
      <Icon className="w-4 h-4" />
      <span className="text-sm">{label}</span>
    </Link>
  );
}
