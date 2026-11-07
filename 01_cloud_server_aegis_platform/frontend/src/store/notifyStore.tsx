import { create } from 'zustand';
import toast from 'react-hot-toast';

export interface AppNotification {
  id: string;
  title: string;
  message: string;
  isRead: boolean;
  timestamp: Date;
  link?: string;
}

interface NotifyState {
  notifications: AppNotification[];
  isGenerating: boolean;
  addNotification: (n: Omit<AppNotification, 'id' | 'timestamp' | 'isRead'>) => void;
  markAllAsRead: () => void;
  generateReport: () => Promise<void>;
}

export const useNotifyStore = create<NotifyState>((set, get) => ({
  notifications: [],
  isGenerating: false,
  
  addNotification: (notif) => {
    const newNotif = {
      ...notif,
      id: Math.random().toString(36).substring(7),
      timestamp: new Date(),
      isRead: false
    };
    
    set((state) => ({ notifications: [newNotif, ...state.notifications] }));
    
    // 🌟 macOS 風格的通知彈窗
    toast.custom((t) => (
      <div className={`${t.visible ? 'animate-in slide-in-from-top-5' : 'animate-out fade-out'} max-w-md w-full bg-slate-800 border border-slate-700 shadow-2xl rounded-xl pointer-events-auto flex ring-1 ring-black ring-opacity-5 overflow-hidden`}>
        <div className="flex-1 p-4">
          <div className="flex items-start">
            <div className="ml-3 flex-1">
              <p className="text-sm font-bold text-white">{notif.title}</p>
              <p className="mt-1 text-sm text-slate-400">{notif.message}</p>
            </div>
          </div>
        </div>
        <div className="flex border-l border-slate-700">
          <button onClick={() => toast.dismiss(t.id)} className="w-full border border-transparent rounded-none rounded-r-lg p-4 flex items-center justify-center text-sm font-medium text-indigo-400 hover:text-indigo-300 hover:bg-slate-700 transition-colors">
            Close
          </button>
        </div>
      </div>
    ), { duration: 5000, position: 'top-right' });
  },
  
  markAllAsRead: () => set((state) => ({
    notifications: state.notifications.map(n => ({ ...n, isRead: true }))
  })),

  // 🌟 全局背景生成邏輯
  generateReport: async () => {
    if (get().isGenerating) return;
    set({ isGenerating: true });
    
    // 模擬 AI 生成時間 (5 秒)，這段期間使用者可以隨意切換網頁
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    set({ isGenerating: false });
    get().addNotification({
      title: '✅ AI Report Ready',
      message: 'Your Data Analytics & Threat Intelligence report has been generated successfully.',
      link: '/analytics' // 點擊通知時跳轉的目標
    });
  }
}));
