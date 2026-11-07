'use client';
import React from 'react';
import { Bell } from 'lucide-react';
import { useNotifyStore } from '@/store/notifyStore';

export default function NotificationBell() {
  const { notifications, markAllAsRead } = useNotifyStore();
  const unreadCount = notifications.filter(n => !n.isRead).length;

  return (
    <button 
      onClick={markAllAsRead}
      className="relative p-2 text-gray-400 hover:text-white transition-colors outline-none border-none focus:outline-none"
    >
      <Bell className="w-6 h-6" />
      {unreadCount > 0 && (
        <span className="absolute top-1 right-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[10px] font-bold text-white shadow-[0_0_0_2px_#0f172a]">
          {unreadCount}
        </span>
      )}
    </button>
  );
}
