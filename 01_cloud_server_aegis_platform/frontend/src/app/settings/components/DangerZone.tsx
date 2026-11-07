'use client';
import { AlertTriangle, Trash2 } from 'lucide-react';

export default function DangerZone({ token, onSuccess }: { token: string, onSuccess: (msg: string) => void }) {
  const handleClearHistory = async () => {
    if (!window.confirm("⚠️ 警告：這將會永久刪除所有事件與截圖，確定繼續？")) return;
    try {
      // 🌟 修正：網址加上 /clear，並嚴格檢查 res.ok
      const res = await fetch('/api/v1/events/clear', { method: 'DELETE', headers: { 'Authorization': `Bearer ${token}` } });
      if (res.ok) {
        onSuccess('🔥 資料庫已徹底清空！');
      } else {
        alert('❌ 清空失敗！請檢查伺服器端連線。');
      }
    } catch(e) {
      alert('❌ 網路請求錯誤！');
    }
  };

  return (
    <div className="bg-slate-900 border border-rose-900/50 rounded-xl p-6 shadow-xl relative overflow-hidden">
      <div className="absolute top-0 left-0 w-1 h-full bg-rose-500"></div>
      <h2 className="text-xl font-semibold text-rose-400 mb-4 flex items-center"><AlertTriangle className="w-5 h-5 mr-2" /> 危險操作區域 (Danger Zone)</h2>
      <div className="flex justify-between items-center bg-slate-950/50 p-4 rounded-lg border border-rose-500/10">
        <div>
          <h3 className="text-white font-medium">清空所有歷史事件與照片</h3>
          <p className="text-sm text-slate-400 mt-1">立刻刪除資料庫中所有 Event Log 以及儲存的截圖 (無法復原)。</p>
        </div>
        <button onClick={handleClearHistory} className="bg-rose-500/10 hover:bg-rose-500 hover:text-white text-rose-400 px-4 py-2 rounded-lg text-sm flex items-center transition-colors">
          <Trash2 className="w-4 h-4 mr-2" />一鍵清空
        </button>
      </div>
    </div>
  );
}
