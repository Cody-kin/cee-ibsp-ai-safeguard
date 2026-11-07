'use client';
import { useState, useEffect } from 'react';
import { Settings, User } from 'lucide-react';
import { useLangStore } from '@/store/langStore';
import toast from 'react-hot-toast';

// 🌟 這裡就是關鍵：把三個寫好 API 邏輯的元件正確載入
import UserManagement from './components/UserManagement';
import DatabaseSettings from './components/DatabaseSettings';
import DangerZone from './components/DangerZone';

export default function SettingsPage() {
  const { t, lang } = useLangStore();
  const [profile, setProfile] = useState<any>(null);
  const [token, setToken] = useState('');

  useEffect(() => {
    const tk = localStorage.getItem('token');
    if (tk) {
      setToken(tk);
      fetch('/api/v1/users/me', { headers: { 'Authorization': `Bearer ${tk}` } })
        .then(async res => {
          if (!res.ok) {
            localStorage.removeItem('token');
            window.location.href = '/login'; 
            throw new Error("Session expired");
          }
          return res.json();
        })
        .then(data => setProfile(data))
        .catch(err => console.error(err));
    } else {
      window.location.href = '/login';
    }
  }, []);

  if (!profile) return <div className="p-20 text-center text-indigo-400 animate-pulse font-mono text-sm tracking-widest">LOADING SETTINGS...</div>;

  return (
    <div className="p-6 md:p-8 max-w-[1600px] mx-auto space-y-8 pb-10 animate-in fade-in duration-500">
      
      <div className="border-b border-[#1E293B] pb-6">
        <h1 className="text-3xl font-black text-white flex items-center tracking-tight">
          <Settings className="w-8 h-8 mr-4 text-gray-400" /> {t('menuSettings')}
        </h1>
      </div>

      {/* Profile 卡片維持原樣 */}
      <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] p-6 shadow-2xl">
        <h2 className="text-xl font-bold text-white mb-6 flex items-center tracking-wide">
          <User className="w-5 h-5 mr-3 text-indigo-400" /> {t('setProfileTitle')}
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-[#0B0F19] p-5 rounded-2xl border border-[#1E293B] shadow-inner">
            <span className="text-gray-500 block text-xs font-bold uppercase tracking-widest mb-2">Username</span> 
            <span className="font-black text-xl text-white tracking-wide">{profile.username}</span>
          </div>
          <div className="bg-[#0B0F19] p-5 rounded-2xl border border-[#1E293B] shadow-inner">
            <span className="text-gray-500 block text-xs font-bold uppercase tracking-widest mb-2">Role Permission</span> 
            <span className={`px-4 py-1.5 rounded-lg text-xs font-black uppercase tracking-widest inline-block mt-0.5 ${profile.role === 'admin' ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 shadow-sm' : 'bg-[#1E293B] text-gray-300 border border-[#2A3750]'}`}>
              {profile.role}
            </span>
          </div>
        </div>
      </div>

      {/* 🌟 管理員專區：直接渲染你寫好的三個完整元件 */}
      {profile.role === 'admin' && (
        <div className="space-y-8">
          <UserManagement token={token} />
          <DatabaseSettings token={token} onSuccess={(msg) => toast.success(msg, { style: { background: '#172033', color: '#fff', border: '1px solid #2A3750' } })} />
          <DangerZone token={token} onSuccess={(msg) => toast.success(msg, { style: { background: '#172033', color: '#fff', border: '1px solid #2A3750' } })} />
        </div>
      )}
    </div>
  );
}
