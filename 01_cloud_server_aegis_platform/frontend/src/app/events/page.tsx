'use client';
import { useState, useEffect } from 'react';
import { AlertTriangle, Image as ImageIcon, Search } from 'lucide-react';
import { useLangStore } from '@/store/langStore';

export default function EventsPage() {
  const { t } = useLangStore();
  const [events, setEvents] = useState<any[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [severityFilter, setSeverityFilter] = useState('ALL');

  useEffect(() => {
    const fetchEvents = async () => {
      const token = localStorage.getItem('token');
      if (!token) return;
      const res = await fetch('/api/v1/events', { headers: { 'Authorization': `Bearer ${token}` } });
      if (res.ok) { const data = await res.json(); setEvents(data.data); }
    };
    fetchEvents();
  }, []);

  const filteredEvents = events.filter(e => {
    const matchSearch = e.event_name.toLowerCase().includes(searchTerm.toLowerCase()) || e.device_id.toLowerCase().includes(searchTerm.toLowerCase());
    const matchSeverity = severityFilter === 'ALL' || e.severity === severityFilter;
    return matchSearch && matchSeverity;
  });

  return (
    <div className="p-6 md:p-8 max-w-[1600px] mx-auto space-y-8 animate-in fade-in duration-500">
      
      {/* 標題與過濾器區塊 (響應式 Flex 排版) */}
      <div className="flex flex-col xl:flex-row justify-between items-start xl:items-end gap-6 border-b border-[#1E293B] pb-6">
        <div>
          <h1 className="text-3xl font-black text-white flex items-center tracking-tight">
            <AlertTriangle className="w-8 h-8 mr-4 text-rose-400" /> {t('evtTitle')}
          </h1>
          <p className="text-gray-400 mt-2 text-sm font-medium">{t('evtDesc')}</p>
        </div>
        
        <div className="flex flex-col sm:flex-row space-y-3 sm:space-y-0 sm:space-x-4 w-full xl:w-auto">
          <div className="relative flex-1 sm:w-72">
            <Search className="w-4 h-4 absolute left-4 top-1/2 -translate-y-1/2 text-gray-500" />
            <input 
              type="text" 
              placeholder={t('search')} 
              value={searchTerm} 
              onChange={(e) => setSearchTerm(e.target.value)} 
              className="w-full bg-[#0B0F19] border border-[#2A3750] text-white rounded-xl pl-11 pr-4 py-3 text-sm outline-none focus:border-indigo-500 transition-colors shadow-inner" 
            />
          </div>
          <select 
            value={severityFilter} 
            onChange={(e) => setSeverityFilter(e.target.value)} 
            className="bg-[#0B0F19] border border-[#2A3750] text-white rounded-xl px-4 py-3 text-sm outline-none focus:border-indigo-500 transition-colors shadow-inner cursor-pointer"
          >
            <option value="ALL">{t('evtAll')}</option>
            <option value="critical">{t('critical')}</option>
            <option value="high">{t('high')}</option>
            <option value="info">{t('info')}</option>
          </select>
        </div>
      </div>

      {/* 🌟 核心防破版表格容器 */}
      <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] shadow-2xl overflow-hidden">
        {/* overflow-x-auto 讓表格在窄螢幕可以水平滑動 */}
        <div className="overflow-x-auto custom-scrollbar">
          <table className="w-full text-left text-sm text-gray-300 min-w-[800px]">
            <thead className="bg-[#0B0F19] text-gray-500 text-xs uppercase tracking-widest border-b border-[#1E293B]">
              <tr>
                <th className="px-6 py-5 font-bold">{t('colTime')}</th>
                <th className="px-6 py-5 font-bold">{t('colNode')}</th>
                <th className="px-6 py-5 font-bold">{t('colEvent')}</th>
                <th className="px-6 py-5 font-bold">{t('colSeverity')}</th>
                <th className="px-6 py-5 font-bold">{t('colDesc')}</th>
                <th className="px-6 py-5 font-bold text-center">{t('colSnap')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#1E293B]/50">
              {filteredEvents.map(evt => (
                <tr key={evt.id} className="hover:bg-[#1E293B]/40 transition-colors">
                  <td className="px-6 py-4 font-mono text-xs text-gray-400">
                    {new Date(evt.timestamp.endsWith('Z') ? evt.timestamp : evt.timestamp + 'Z').toLocaleString()}
                  </td>
                  <td className="px-6 py-4 font-mono text-indigo-400 font-bold tracking-wide">{evt.device_id}</td>
                  <td className="px-6 py-4 font-bold text-gray-200">{evt.event_name}</td>
                  <td className="px-6 py-4">
                    <span className={`px-2.5 py-1 rounded-lg text-[10px] font-black uppercase tracking-wider ${evt.severity === 'critical' ? 'bg-red-500/10 text-red-400 border border-red-500/20' : evt.severity === 'high' ? 'bg-orange-500/10 text-orange-400 border border-orange-500/20' : 'bg-blue-500/10 text-blue-400 border border-blue-500/20'}`}>
                      {t(evt.severity as any) || evt.severity}
                    </span>
                  </td>
                  <td className="px-6 py-4 max-w-xs truncate text-gray-400" title={evt.description}>
                    {evt.description}
                  </td>
                  <td className="px-6 py-4 text-center">
                    {evt.has_image ? (
                      <a href={`/storage/evt_${evt.id}_${evt.event_type}.jpg`} target="_blank" rel="noreferrer" className="inline-flex p-2 bg-[#1E293B] hover:bg-indigo-600 text-gray-300 hover:text-white rounded-lg transition-colors shadow-sm">
                        <ImageIcon className="w-4 h-4" />
                      </a>
                    ) : (
                      <span className="text-gray-600 text-xs italic font-medium">{t('noImage')}</span>
                    )}
                  </td>
                </tr>
              ))}
              {filteredEvents.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-6 py-16 text-center text-gray-500 font-mono text-sm">
                    {t('evtEmpty')}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
