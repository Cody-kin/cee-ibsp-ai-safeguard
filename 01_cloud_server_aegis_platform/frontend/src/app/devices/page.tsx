'use client';
import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { Cpu, Flame, Wind, UserX, User, ShieldAlert, Video, Users, HardHat, Shirt, Cigarette, Smartphone, Server, Radio, Check, Search, X, Terminal, Play, Square, Trash2 } from 'lucide-react';
import toast from 'react-hot-toast';

export default function DevicesPage() {
  const router = useRouter();
  const [devices, setDevices] = useState<any[]>([]);
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [allUsers, setAllUsers] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  // 權限 Modal 狀態
  const [assignModalCam, setAssignModalCam] = useState<any>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [tempAssignees, setTempAssignees] = useState<string[]>([]);

  // 🌟 系統終端機 Modal 狀態
  const [showSysConsole, setShowSysConsole] = useState(false);
  const [sysLogs, setSysLogs] = useState<any[]>([]);
  const [clearTime, setClearTime] = useState<number>(0);
  const logsEndRef = useRef<HTMLDivElement>(null);

  // 初始化資料
  useEffect(() => {
    const initData = async () => {
      const token = localStorage.getItem('token');
      const headers: Record<string, string> = token ? { 'Authorization': `Bearer ${token}` } : {};

      try {
        if (token) {
          const meRes = await fetch(`/api/v1/users/me?_t=${Date.now()}`, { headers });
          if (meRes.ok) {
            const meData = await meRes.json();
            setCurrentUser(meData);
            if (meData.role === 'admin') {
              const usersRes = await fetch(`/api/v1/users?_t=${Date.now()}`, { headers });
              if (usersRes.ok) setAllUsers((await usersRes.json()).data || []);
            }
          }
        }
        const devRes = await fetch(`/api/v1/devices?_t=${Date.now()}`, { headers });
        if (devRes.ok) setDevices((await devRes.json()).data || []);
      } catch (err) {} finally { setIsLoading(false); }
    };
    
    initData();
    setClearTime(parseInt(localStorage.getItem('sysLogClearTime') || '0'));

    const interval = setInterval(() => {
      const token = localStorage.getItem('token');
      fetch(`/api/v1/devices?_t=${Date.now()}`, { headers: token ? { 'Authorization': `Bearer ${token}` } : {} })
        .then(res => res.json())
        .then(data => setDevices(data.data || []))
        .catch(() => {});
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  // 🌟 系統終端機：動態抓取 sys_log 封包
  useEffect(() => {
    if (!showSysConsole) return;
    const fetchLogs = async () => {
      const token = localStorage.getItem('token');
      try {
        const res = await fetch(`/api/v1/events?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (res.ok) {
          const data = await res.json();
          const logs = (data.data || []).filter((e: any) => e.event_type === 'system_log' || e.event_type === 'sys_log');
          setSysLogs(logs.sort((a: any, b: any) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()));
        }
      } catch (err) {}
    };
    fetchLogs();
    const logInterval = setInterval(fetchLogs, 2000);
    return () => clearInterval(logInterval);
  }, [showSysConsole]);

  // 自動捲動到日誌最底部
  useEffect(() => {
    logsEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [sysLogs]);

  // 🌟 發送 SYS 遙控指令
  const sendSysCommand = async (cmd: string) => {
    const token = localStorage.getItem('token');
    try {
      const res = await fetch('/api/v1/devices/NANO-001/system_command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ command: cmd })
      });
      if (!res.ok) {
        toast.error(`伺服器拒絕請求 (錯誤碼: ${res.status})`);
        return;
      }
      toast.success(`已下發系統指令: SYS|${cmd}`, { icon: '📡', style: { background: '#172033', color: '#fff' }});
    } catch (e) {
      toast.error('網路連線異常，指令發送失敗');
    }
  };

  // 🌟 自主清除日誌 (僅限本地 UI 隱藏，不刪資料庫)
  const handleClearLogs = () => {
    const now = Date.now();
    setClearTime(now);
    localStorage.setItem('sysLogClearTime', now.toString());
    toast.success('本機日誌畫面已清空');
  };

  const handleUpdateConfig = async (camId: string, field: string, value: any) => {
    if (currentUser?.role !== 'admin') return;
    const targetCam = devices.find(c => c.id === camId);
    if (!targetCam) return;

    const newConfig = { ...targetCam.config, [field]: value };
    setDevices(prev => prev.map(c => c.id === camId ? { ...c, config: newConfig } : c));

    try {
      const token = localStorage.getItem('token');
      await fetch(`/api/v1/devices/${camId}/config`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', ...(token && { 'Authorization': `Bearer ${token}` }) },
        body: JSON.stringify(newConfig)
      });
      if (field === 'assignees') toast.success('權限分配已更新', { style: { background: '#10b981', color: '#fff' }});
    } catch (e) {}
  };

  const openAssignModal = (cam: any) => { setAssignModalCam(cam); setTempAssignees(cam.config?.assignees || ['admin']); setSearchQuery(''); };
  const closeAssignModal = () => { setAssignModalCam(null); setTempAssignees([]); };
  const toggleTempUser = (username: string) => { setTempAssignees(prev => prev.includes(username) ? prev.filter(u => u !== username) : [...prev, username]); };
  const saveAssignments = () => { if (assignModalCam) { handleUpdateConfig(assignModalCam.id, 'assignees', tempAssignees); closeAssignModal(); } };

  if (isLoading) return <div className="p-8 text-indigo-400 font-mono animate-pulse">驗證權限與載入設備中...</div>;

  const isAdmin = currentUser?.role === 'admin';
  
  let infraDevices = devices.filter(d => d.type === 'host' || d.type === 'gateway');
  if (infraDevices.length === 0) {
    infraDevices = [
      { id: 'NANO-001', name: 'Jetson Nano AI 主機', type: 'host', status: 'offline' },
      { id: 'LORA-001', name: 'LoRa 緊急通訊網關', type: 'gateway', status: 'offline' }
    ];
  }

  const cameraDevices = devices.filter(d => {
    if (d.type !== 'camera') return false;
    if (isAdmin) return true;
    const assignees = d.config?.assignees || ['admin'];
    return assignees.includes(currentUser?.username) || assignees.includes(currentUser?.id?.toString());
  });

  const aiModels = [
    { key: 'fire', label: '火災', icon: Flame, color: 'text-rose-400', accent: 'accent-rose-500' },
    { key: 'smoke', label: '煙霧', icon: Wind, color: 'text-amber-400', accent: 'accent-amber-500' },
    { key: 'fall', label: '跌倒', icon: UserX, color: 'text-indigo-400', accent: 'accent-indigo-500' },
    { key: 'hardhat', label: '安全帽', icon: HardHat, color: 'text-yellow-400', accent: 'accent-yellow-500' },
    { key: 'vest', label: '反光衣', icon: Shirt, color: 'text-orange-400', accent: 'accent-orange-500' },
    { key: 'smoking', label: '抽菸', icon: Cigarette, color: 'text-red-400', accent: 'accent-red-500' },
    { key: 'phone', label: '玩手機', icon: Smartphone, color: 'text-blue-400', accent: 'accent-blue-500' }
  ];

  const filteredUsers = allUsers.filter(u => u.role !== 'admin' && (u.username?.toLowerCase().includes(searchQuery.toLowerCase()) || u.email?.toLowerCase().includes(searchQuery.toLowerCase())));
  const visibleLogs = sysLogs.filter(log => new Date(log.timestamp.endsWith('Z') ? log.timestamp : log.timestamp + 'Z').getTime() > clearTime);

  return (
    <div className="p-8 max-w-[1400px] mx-auto space-y-8 animate-in fade-in relative">
      <div className="flex justify-between items-end border-b border-[#1E293B] pb-6">
        <div>
          <h1 className="text-3xl font-black text-white flex items-center"><ShieldAlert className="w-8 h-8 mr-4 text-emerald-400" /> 設備總管與 AI 權限派發</h1>
          <p className="text-gray-400 mt-2 text-sm font-medium">支援多重用戶派發與底層系統遙控</p>
        </div>
        <div className="bg-[#131B2C] border border-[#1E293B] px-4 py-2 rounded-xl flex items-center shadow-lg">
          <User className="w-4 h-4 mr-2 text-indigo-400" />
          <span className="text-white text-sm font-bold mr-2">{currentUser?.username || '未登入'}</span>
          <span className={`text-[10px] font-black px-2 py-0.5 rounded tracking-wider ${isAdmin ? 'bg-rose-500/20 text-rose-400' : 'bg-blue-500/20 text-blue-400'}`}>
            {isAdmin ? 'ADMIN' : 'USER'}
          </span>
        </div>
      </div>

      {/* 基礎設施 */}
      <div>
        <h2 className="text-xl font-bold text-white mb-4 flex items-center"><Server className="w-5 h-5 mr-2 text-gray-400"/> 基礎設施狀態</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {infraDevices.map(dev => {
            const isOnline = dev.status === 'online';
            const isNano = dev.type === 'host';
            const isLora = dev.id === 'LORA-001' || dev.type === 'gateway';
            return (
            <div 
              key={dev.id} 
              // 🌟 點擊 Nano 卡片開啟 Console (僅限 Admin)
              onClick={() => { if (isNano && isAdmin) setShowSysConsole(true); else if (isLora) router.push('/devices/lora'); }}
              className={`bg-[#131B2C] border ${isOnline ? 'border-[#1E293B]' : 'border-red-900/30'} p-5 rounded-2xl flex items-center shadow-lg transition-all duration-300 ${(isNano && isAdmin) || isLora ? 'cursor-pointer hover:border-indigo-500/50 hover:shadow-indigo-500/10 hover:-translate-y-1' : ''}`}
            >
              <div className={`w-12 h-12 rounded-full flex items-center justify-center mr-4 transition-colors ${isOnline ? (isNano ? 'bg-indigo-500/10 border border-indigo-500/30' : 'bg-emerald-500/10 border border-emerald-500/30') : 'bg-gray-800/50 border border-gray-700'}`}>
                {isNano ? <Cpu className={`w-6 h-6 transition-colors ${isOnline ? 'text-indigo-400' : 'text-gray-500'}`} /> : <Radio className={`w-6 h-6 transition-colors ${isOnline ? 'text-emerald-400' : 'text-gray-500'}`} />}
              </div>
              <div>
                <h3 className={`font-bold transition-colors ${isOnline ? 'text-white' : 'text-gray-400'}`}>{dev.name}</h3>
                <p className="text-xs font-mono mt-0.5 flex items-center gap-2">
                  <span className="text-gray-500">ID: {dev.id}</span>
                  {isNano && isAdmin && <span className="text-[9px] bg-indigo-500/20 text-indigo-300 px-1.5 py-0.5 rounded border border-indigo-500/30">點擊開啟控制台</span>}
                  {isLora && <span className="text-[9px] bg-emerald-500/20 text-emerald-300 px-1.5 py-0.5 rounded border border-emerald-500/30">點擊查看 LoRa 詳情</span>}
                </p>
              </div>
              <div className="ml-auto flex items-center">
                <span className={`w-2 h-2 rounded-full mr-2 transition-colors ${isOnline ? 'bg-emerald-400 animate-pulse' : 'bg-gray-600'}`}></span>
                <span className={`text-xs font-bold tracking-widest transition-colors ${isOnline ? 'text-emerald-400' : 'text-gray-500'}`}>{isOnline ? 'ONLINE' : 'OFFLINE'}</span>
              </div>
            </div>
          )})}
        </div>
      </div>

      {/* AI 監控終端區塊... (保持不變) */}
      <div>
        <h2 className="text-xl font-bold text-white mb-4 flex items-center mt-8"><Video className="w-5 h-5 mr-2 text-indigo-400"/> AI 監控終端</h2>
        <div className="space-y-6">
          {cameraDevices.length === 0 ? (
             <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] p-12 text-center shadow-lg"><Video className="w-12 h-12 text-gray-600 mx-auto mb-4" /><p className="text-gray-400">目前沒有在線的鏡頭，或無分配給您的權限。</p></div>
          ) : cameraDevices.map(cam => {
            const assignees = cam.config?.assignees || ['admin'];
            const assignedCount = assignees.filter((a: string) => a !== 'admin').length;
            
            return (
            <div key={cam.id} className={`bg-[#131B2C] border ${isAdmin ? 'border-[#1E293B] hover:border-indigo-500/50' : 'border-[#1E293B]'} rounded-2xl p-6 shadow-lg transition-colors`}>
              <div className="flex flex-col xl:flex-row justify-between mb-6">
                <div className="flex items-center mb-6 xl:mb-0">
                  <div className="w-14 h-14 bg-indigo-500/10 rounded-full flex items-center justify-center border border-indigo-500/30 mr-5 shadow-inner"><Video className="w-7 h-7 text-indigo-400" /></div>
                  <div><h3 className="text-lg font-bold text-white tracking-wide">{cam.name}</h3><p className="text-sm text-gray-500 font-mono mt-1">ID: {cam.id}</p></div>
                </div>
                {isAdmin && (
                  <div className="flex items-center">
                    <button onClick={() => openAssignModal(cam)} className="flex items-center gap-2 bg-[#0B0F19] hover:bg-indigo-500/10 border border-[#1E293B] hover:border-indigo-500/30 transition-all px-5 py-3 rounded-xl shadow-inner group">
                      <Users className="w-5 h-5 text-gray-400 group-hover:text-indigo-400 transition-colors" />
                      <div className="flex flex-col items-start"><span className="text-[10px] text-gray-500 font-bold uppercase tracking-widest leading-none mb-1">觀看權限</span><span className="text-sm font-bold text-white leading-none">已派發給 {assignedCount} 人</span></div>
                    </button>
                  </div>
                )}
              </div>
              <div className={`grid grid-cols-2 md:grid-cols-4 xl:grid-cols-7 gap-4 bg-[#0B0F19] p-5 rounded-xl border border-[#1E293B] shadow-inner ${!isAdmin ? 'opacity-70 pointer-events-none' : ''}`}>
                {aiModels.map((model) => {
                  const val = cam.config?.[model.key] || 0;
                  const isOn = val > 0;
                  return (
                  <div key={model.key} className={`flex flex-col p-3 rounded-xl border transition-colors ${isOn ? 'bg-[#131B2C] border-[#2A3750]' : 'bg-transparent border-transparent opacity-50 hover:opacity-100'}`}>
                    <div className="flex justify-between items-center mb-3">
                      <span className="text-xs font-bold text-gray-300 uppercase tracking-wide flex items-center"><model.icon className={`w-4 h-4 mr-1.5 ${isOn ? model.color : 'text-gray-500'}`}/>{model.label}</span>
                      <span className={`text-xs font-mono font-bold px-1.5 py-0.5 rounded ${isOn ? 'bg-emerald-500/20 text-emerald-400' : 'bg-gray-800 text-gray-500'}`}>{isOn ? `${Math.round(val * 100)}%` : 'OFF'}</span>
                    </div>
                    <input type="range" min="0" max="1" step="0.05" value={val} onChange={(e) => handleUpdateConfig(cam.id, model.key, parseFloat(e.target.value))} className={`w-full h-1.5 bg-gray-700 rounded-lg appearance-none cursor-pointer ${model.accent}`} />
                  </div>
                )})}
              </div>
            </div>
          )})}
        </div>
      </div>

      {/* 🌟 系統遙控與日誌 Terminal Modal */}
      {showSysConsole && (
        <div className="fixed inset-0 z-[110] flex items-center justify-center bg-black/80 backdrop-blur-sm px-4 animate-in fade-in zoom-in-95 duration-200">
           <div className="bg-[#0B0F19] border border-[#2A3750] rounded-[1.5rem] shadow-[0_0_50px_rgba(0,0,0,0.8)] w-full max-w-4xl flex flex-col h-[75vh] overflow-hidden relative">
            
            {/* Header */}
            <div className="p-4 border-b border-[#1E293B] flex justify-between items-center bg-[#131B2C]">
              <div className="flex items-center gap-3">
                <Terminal className="w-5 h-5 text-indigo-400" />
                <h3 className="text-white text-lg font-black tracking-wide font-mono">NANO-001 / SYSTEM_CONSOLE</h3>
                <span className="bg-emerald-500/20 text-emerald-400 text-[10px] font-bold px-2 py-0.5 rounded border border-emerald-500/30 ml-2 animate-pulse">LORA LINK ACTIVE</span>
              </div>
              <button onClick={() => setShowSysConsole(false)} className="text-gray-500 hover:text-white transition-colors p-1.5"><X className="w-6 h-6" /></button>
            </div>
            
            {/* Body */}
            <div className="flex flex-1 overflow-hidden flex-col md:flex-row">
              
              {/* Left Panel: Controls */}
              <div className="w-full md:w-64 bg-[#131B2C] border-b md:border-b-0 md:border-r border-[#1E293B] p-6 flex flex-col gap-4">
                <p className="text-xs text-gray-500 font-bold uppercase tracking-widest mb-2">Power Controls</p>
                
                <button onClick={() => sendSysCommand('START')} className="w-full bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/30 text-emerald-400 rounded-xl p-4 flex flex-col items-center justify-center gap-3 transition-all group">
                  <div className="bg-emerald-500/20 p-3 rounded-full group-hover:scale-110 transition-transform"><Play className="w-6 h-6 fill-emerald-400" /></div>
                  <span className="font-bold tracking-widest">喚醒防護 (START)</span>
                </button>
                
                <button onClick={() => sendSysCommand('STOP')} className="w-full bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/30 text-rose-400 rounded-xl p-4 flex flex-col items-center justify-center gap-3 transition-all group">
                  <div className="bg-rose-500/20 p-3 rounded-full group-hover:scale-110 transition-transform"><Square className="w-6 h-6 fill-rose-400" /></div>
                  <span className="font-bold tracking-widest">深度待命 (STOP)</span>
                </button>

                <div className="mt-auto pt-4 border-t border-[#1E293B]">
                  <button onClick={handleClearLogs} className="w-full flex items-center justify-center gap-2 text-xs font-bold text-gray-500 hover:text-white transition-colors p-2">
                    <Trash2 className="w-4 h-4" /> 清除本機日誌畫面
                  </button>
                </div>
              </div>

              {/* Right Panel: Terminal Log */}
              <div className="flex-1 bg-black p-4 font-mono text-sm overflow-y-auto custom-scrollbar flex flex-col gap-1.5 shadow-inner">
                <div className="text-gray-500 mb-4 pb-2 border-b border-gray-800">
                  <p>Aegis OS [Version 2.0.1]</p>
                  <p>(c) AI-SafeGuard Corporation. All rights reserved.</p>
                  <p className="mt-2 text-indigo-500/70">Waiting for sys_log telemetry via LoRa...</p>
                </div>

                {visibleLogs.length === 0 ? (
                  <div className="text-gray-600 italic">No recent system logs.</div>
                ) : (
                  visibleLogs.map((log, idx) => {
                    const isCrit = log.severity === 'critical';
                    const isWarn = log.severity === 'warning';
                    const time = new Date(log.timestamp.endsWith('Z') ? log.timestamp : log.timestamp + 'Z').toLocaleTimeString();
                    return (
                      <div key={idx} className={`flex items-start gap-3 hover:bg-white/5 p-1 rounded transition-colors ${isCrit ? 'text-red-400' : isWarn ? 'text-yellow-400' : 'text-emerald-400'}`}>
                        <span className="text-gray-600 shrink-0">[{time}]</span>
                        <span className="shrink-0 w-12 font-bold">{isCrit ? 'CRIT' : isWarn ? 'WARN' : 'INFO'}</span>
                        <span className="break-all">{log.description || log.event_name}</span>
                      </div>
                    );
                  })
                )}
                <div ref={logsEndRef} /> {/* 用來自動捲動到底部 */}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 舊有的權限分配 Modal ... (保持原樣) */}
      {assignModalCam && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-sm px-4 animate-in fade-in duration-200">
           <div className="bg-[#131B2C] border border-[#2A3750] rounded-[2rem] shadow-2xl w-full max-w-md flex flex-col max-h-[85vh] overflow-hidden">
            <div className="p-6 border-b border-[#1E293B] flex justify-between items-center bg-[#172033]">
              <div><h3 className="text-white text-xl font-black flex items-center tracking-wide"><Users className="w-6 h-6 mr-3 text-indigo-400" /> 分配觀看權限</h3><p className="text-gray-400 text-xs mt-1 font-mono">{assignModalCam.name}</p></div>
              <button onClick={closeAssignModal} className="text-gray-500 hover:text-white transition-colors bg-[#0B0F19] p-2 rounded-xl border border-[#2A3750]"><X className="w-5 h-5" /></button>
            </div>
            <div className="p-6 flex flex-col flex-1 overflow-hidden">
              <div className="relative mb-4">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                <input type="text" placeholder="搜尋使用者名稱..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} className="w-full bg-[#0B0F19] border border-[#2A3750] text-white text-sm rounded-xl pl-10 pr-4 py-3 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all" />
              </div>
              <div className="flex-1 overflow-y-auto custom-scrollbar space-y-2 pr-2">
                {filteredUsers.length === 0 ? (<div className="text-center text-gray-500 font-mono py-8">找不到符合的使用者</div>) : (
                  filteredUsers.map(user => {
                    const isSelected = tempAssignees.includes(user.username);
                    return (
                      <div key={user.id} onClick={() => toggleTempUser(user.username)} className={`flex items-center justify-between p-3 rounded-xl cursor-pointer transition-all border ${isSelected ? 'bg-indigo-500/10 border-indigo-500/30' : 'bg-[#0B0F19] border-[#1E293B] hover:border-[#2A3750]'}`}>
                        <div className="flex items-center"><div className={`w-8 h-8 rounded-full flex items-center justify-center mr-3 font-bold text-xs ${isSelected ? 'bg-indigo-500 text-white' : 'bg-gray-800 text-gray-400'}`}>{user.username.substring(0, 2).toUpperCase()}</div><span className={`font-bold ${isSelected ? 'text-indigo-300' : 'text-gray-300'}`}>{user.username}</span></div>
                        <div className={`w-5 h-5 rounded border flex items-center justify-center transition-colors ${isSelected ? 'bg-indigo-500 border-indigo-500' : 'border-gray-600'}`}>{isSelected && <Check className="w-3.5 h-3.5 text-white" />}</div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
            <div className="p-6 border-t border-[#1E293B] bg-[#0B0F19] flex justify-end gap-3">
              <button onClick={closeAssignModal} className="px-5 py-2.5 rounded-xl text-gray-400 text-sm font-bold hover:text-white hover:bg-[#1E293B] transition-colors">取消</button>
              <button onClick={saveAssignments} className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-bold transition-colors shadow-lg shadow-indigo-500/25">確認套用</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
