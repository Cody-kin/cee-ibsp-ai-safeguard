'use client';
import { useState, useRef, useEffect } from 'react';
import { Bell, Check, AlertTriangle, Info } from 'lucide-react';
import { useNotifStore } from '@/store/notifStore';
import { useLangStore } from '@/store/langStore';

export default function TopHeader() {
  const { t } = useLangStore();
  const { notifs, markAllRead, getUnreadCount } = useNotifStore();
  const [isOpen, setIsOpen] = useState(false);
  const unread = getUnreadCount();

  return (
    <div className="flex justify-end items-center mb-6 relative z-40">
      <button onClick={() => setIsOpen(!isOpen)} className="relative p-2 text-slate-400 hover:text-white bg-slate-900 border border-slate-800 rounded-full transition-colors">
        <Bell className="w-5 h-5" />
        {unread > 0 && <span className="absolute top-0 right-0 w-2.5 h-2.5 bg-rose-500 rounded-full border-2 border-slate-900"></span>}
      </button>

      {isOpen && (
        <div className="absolute top-12 right-0 w-80 bg-slate-900 border border-slate-700 rounded-xl shadow-2xl overflow-hidden">
          <div className="flex justify-between items-center p-4 border-b border-slate-800 bg-slate-950/50">
            <h4 className="text-sm font-bold text-white">{t('notifTitle')}</h4>
            {unread > 0 && <button onClick={markAllRead} className="text-xs text-indigo-400 hover:text-indigo-300 flex items-center"><Check className="w-3 h-3 mr-1"/>{t('markRead')}</button>}
          </div>
          <div className="max-h-80 overflow-y-auto custom-scrollbar">
            {notifs.length === 0 ? (
              <p className="p-6 text-center text-sm text-slate-500">{t('notifEmpty')}</p>
            ) : (
              notifs.map(n => (
                <div key={n.id} className={`p-4 border-b border-slate-800/50 hover:bg-slate-800/50 transition-colors ${!n.read ? 'bg-slate-800/20' : ''}`}>
                  <div className="flex items-start">
                    {n.type === 'alert' ? <AlertTriangle className="w-4 h-4 text-rose-400 mt-0.5 mr-3 flex-shrink-0" /> : <Info className="w-4 h-4 text-blue-400 mt-0.5 mr-3 flex-shrink-0" />}
                    <div>
                      <h5 className={`text-sm font-medium ${!n.read ? 'text-white' : 'text-slate-300'}`}>{n.title}</h5>
                      <p className="text-xs text-slate-500 mt-1 leading-relaxed">{n.message}</p>
                      <span className="text-[10px] text-slate-600 mt-2 block">{new Date(n.time).toLocaleTimeString()}</span>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}
