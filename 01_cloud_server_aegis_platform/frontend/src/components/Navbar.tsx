'use client';
import { useState, useRef, useEffect } from 'react';
import { Shield, Bell, User, LogOut, Settings, CheckCheck, FileText } from 'lucide-react';
import { useLangStore } from '@/store/langStore';
import { useNotifyStore } from '@/store/notifyStore';
import { useRouter } from 'next/navigation';

export default function Navbar() {
  const { lang, setLang, t } = useLangStore();
  const { notifications, markAllAsRead } = useNotifyStore();
  const [showProfileMenu, setShowProfileMenu] = useState(false);
  const [showNotifyMenu, setShowNotifyMenu] = useState(false);
  const router = useRouter();
  
  const notifyRef = useRef<HTMLDivElement>(null);

  const unreadCount = notifications.filter(n => !n.isRead).length;

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (notifyRef.current && !notifyRef.current.contains(event.target as Node)) {
        setShowNotifyMenu(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('token');
    window.location.href = '/';
  };

  const handleNotificationClick = (link?: string) => {
    setShowNotifyMenu(false);
    if (link) router.push(link);
  };

  return (
    <nav className="bg-slate-900 border-b border-slate-800 sticky top-0 z-50 shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16 items-center">
          
          <div className="flex items-center cursor-pointer" onClick={() => router.push('/')}>
            <Shield className="w-8 h-8 text-indigo-500 mr-2" />
            <span className="text-xl font-bold text-white tracking-wider">AI-SafeGuard</span>
          </div>

          <div className="flex items-center space-x-6 relative">
            
            <select value={lang} onChange={(e) => setLang(e.target.value as 'en'|'zh')} className="bg-slate-800 text-slate-300 text-sm rounded border border-slate-700 px-2 py-1 outline-none">
              <option value="en">EN</option><option value="zh">繁體中文</option>
            </select>

            <button onClick={() => router.push('/')} className="text-slate-400 hover:text-white text-sm font-medium transition-colors">{t('menuDashboard')}</button>
            <button onClick={() => router.push('/analytics')} className="text-slate-400 hover:text-white text-sm font-medium transition-colors">Analytics</button>
            
            {/* 🌟 鈴鐺與下拉選單 */}
            <div className="relative" ref={notifyRef}>
              <button onClick={() => setShowNotifyMenu(!showNotifyMenu)} className="text-slate-400 hover:text-white transition-colors relative p-1">
                <Bell className="w-5 h-5" />
                {unreadCount > 0 && (
                  <span className="absolute top-0 right-0 block h-2.5 w-2.5 rounded-full bg-rose-500 ring-2 ring-slate-900 animate-pulse"></span>
                )}
              </button>
              
              {showNotifyMenu && (
                <div className="absolute right-0 mt-2 w-80 bg-slate-800 border border-slate-700 rounded-xl shadow-2xl py-2 z-50 animate-in fade-in slide-in-from-top-2">
                  <div className="px-4 py-2 border-b border-slate-700 flex justify-between items-center">
                    <span className="text-white font-bold text-sm">Notifications</span>
                    <button onClick={markAllAsRead} className="text-xs text-indigo-400 hover:text-indigo-300 flex items-center">
                      <CheckCheck className="w-3 h-3 mr-1"/> Mark all read
                    </button>
                  </div>
                  <div className="max-h-64 overflow-y-auto custom-scrollbar">
                    {notifications.length === 0 ? (
                      <div className="px-4 py-6 text-center text-sm text-slate-500">No new notifications.</div>
                    ) : (
                      notifications.map(n => (
                        <div key={n.id} onClick={() => handleNotificationClick(n.link)} className={`px-4 py-3 hover:bg-slate-700 cursor-pointer transition-colors border-b border-slate-700/50 last:border-0 ${!n.isRead ? 'bg-slate-800' : 'opacity-60'}`}>
                          <div className="flex items-start">
                            <FileText className={`w-4 h-4 mr-3 mt-0.5 ${!n.isRead ? 'text-indigo-400' : 'text-slate-500'}`} />
                            <div>
                              <p className={`text-sm ${!n.isRead ? 'text-white font-bold' : 'text-slate-300'}`}>{n.title}</p>
                              <p className="text-xs text-slate-400 mt-1 line-clamp-2">{n.message}</p>
                              <p className="text-[10px] text-slate-500 mt-1 font-mono">{n.timestamp.toLocaleTimeString()}</p>
                            </div>
                          </div>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>

            {/* Profile Dropdown */}
            <div className="relative">
              <button onClick={() => setShowProfileMenu(!showProfileMenu)} className="w-8 h-8 bg-indigo-500/20 rounded-full flex items-center justify-center border border-indigo-500/50 text-indigo-400 hover:bg-indigo-500/30 transition-colors">
                <User className="w-4 h-4" />
              </button>
              {showProfileMenu && (
                <div className="absolute right-0 mt-2 w-48 bg-slate-800 border border-slate-700 rounded-xl shadow-2xl py-2 z-50 animate-in fade-in zoom-in-95">
                  <button onClick={() => { setShowProfileMenu(false); router.push('/settings'); }} className="w-full text-left px-4 py-2 text-sm text-slate-300 hover:bg-slate-700 hover:text-white flex items-center"><Settings className="w-4 h-4 mr-2" /> {t('menuSettings')}</button>
                  <button onClick={handleLogout} className="w-full text-left px-4 py-2 text-sm text-rose-400 hover:bg-slate-700 flex items-center"><LogOut className="w-4 h-4 mr-2" /> {t('btnLogout')}</button>
                </div>
              )}
            </div>
            
          </div>
        </div>
      </div>
    </nav>
  );
}
