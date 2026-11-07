'use client';
import { useState, useEffect } from 'react';
import { Clock, Save } from 'lucide-react';

export default function DatabaseSettings({ token, onSuccess }: { token: string, onSuccess: (msg: string) => void }) {
  const [retentionDays, setRetentionDays] = useState(7);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    fetch('/api/v1/settings', { headers: { 'Authorization': `Bearer ${token}` } })
      .then(res => res.json()).then(data => setRetentionDays(data.retention_days || 7));
  }, [token]);

  const handleSave = async () => {
    setIsSaving(true);
    await fetch('/api/v1/settings', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ retention_days: retentionDays }) });
    onSuccess('✅ 資料庫清理規則已儲存！');
    setIsSaving(false);
  };

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 shadow-xl">
      <h2 className="text-xl font-semibold text-white mb-4 flex items-center"><Clock className="w-5 h-5 mr-2 text-blue-400" /> 資料庫清理規則</h2>
      <div className="space-y-4">
        <p className="text-sm text-slate-400">系統將自動刪除超過指定天數的歷史紀錄。</p>
        <div className="flex items-center space-x-4">
          <select value={retentionDays} onChange={(e) => setRetentionDays(Number(e.target.value))} className="bg-slate-950 border border-slate-700 text-white rounded-lg px-4 py-2 outline-none">
            <option value={1}>1 天</option><option value={3}>3 天</option><option value={7}>7 天</option><option value={30}>30 天</option>
          </select>
          <button onClick={handleSave} disabled={isSaving} className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg text-sm flex items-center"><Save className="w-4 h-4 mr-2"/>儲存</button>
        </div>
      </div>
    </div>
  );
}
