import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export interface AppNotification { id: string; title: string; message: string; type: 'alert' | 'info'; time: number; read: boolean; }
interface NotifState {
  notifs: AppNotification[];
  addNotif: (n: Omit<AppNotification, 'id' | 'time' | 'read'>) => void;
  markAllRead: () => void;
  getUnreadCount: () => number;
}

export const useNotifStore = create<NotifState>()(
  persist((set, get) => ({
    notifs: [],
    addNotif: (n) => set((state) => ({ 
      notifs: [{ ...n, id: Math.random().toString(36).substring(7), time: Date.now(), read: false }, ...state.notifs].slice(0, 50) 
    })),
    markAllRead: () => set((state) => ({ notifs: state.notifs.map(n => ({ ...n, read: true })) })),
    getUnreadCount: () => get().notifs.filter(n => !n.read).length,
  }), { name: 'aegis-notifications' })
);
