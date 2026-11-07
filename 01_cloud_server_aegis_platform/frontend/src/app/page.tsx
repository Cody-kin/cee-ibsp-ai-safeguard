'use client';
import React, { useState, useEffect } from 'react';
import { BrainCircuit, Cpu, Radio, FileText, Activity, Video, History, SlidersHorizontal, X, AlertTriangle, CheckCircle, Flame, Wind, UserX, HardHat, Shirt, Cigarette, Smartphone } from 'lucide-react';
import toast from 'react-hot-toast';
import { useLangStore } from '@/store/langStore';

export default function DashboardPage() {
  const { lang } = useLangStore();
  
  const [showCalibrateModal, setShowCalibrateModal] = useState(false);
  const [showTimelineModal, setShowTimelineModal] = useState(false);
  const [cameras, setCameras] = useState<any[]>([]);
  const [currentUser, setCurrentUser] = useState<any>(null); // 🌟 新增使用者狀態
  const [refreshKey, setRefreshKey] = useState(Date.now());
  const [allEvents, setAllEvents] = useState<any[]>([]);
  const [todaysEvents, setTodaysEvents] = useState<any[]>([]);
  const [deviceStatuses, setDeviceStatuses] = useState<Record<string, string>>({});
  const [loraLatest, setLoraLatest] = useState<any>(null);
  const [now, setNow] = useState(Date.now());

  const [aiState, setAiState] = useState<'safe'|'warning'|'critical'>('safe');
  const [lastSafeTime, setLastSafeTime] = useState(0);

  const [baselineInput, setBaselineInput] = useState('');
  const [mq2Baseline, setMq2Baseline] = useState(0);
  const [latestMq2, setLatestMq2] = useState(0);
  const [latestMq3, setLatestMq3] = useState(0);
  const [isClient, setIsClient] = useState(false);

  useEffect(() => {
    setIsClient(true);
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  const fetchUserAndCameras = async () => {
    try {
      const token = localStorage.getItem('token');
      const headers: Record<string, string> = token ? { 'Authorization': `Bearer ${token}` } : {};

      // 1. 取得當前登入使用者
      if (token && !currentUser) {
        const userRes = await fetch(`/api/v1/users/me?_t=${Date.now()}`, { headers });
        if (userRes.ok) setCurrentUser(await userRes.json());
      }

      // 2. 取得所有設備
      const res = await fetch(`/api/v1/devices?_t=${Date.now()}`, { headers });
      if (res.ok) {
        const data = await res.json();
        const allDevices = data.data || [];
        const statusMap: Record<string, string> = {};
        allDevices.forEach((d: any) => { statusMap[d.id] = d.status; });
        setDeviceStatuses(statusMap);

        const cams = allDevices.filter((d: any) => d.type === 'camera');
        
        setCameras(prev => {
          const prevIds = prev.map(p => p.id).join(',');
          const newIds = cams.map((c: any) => c.id).join(',');
          if (prevIds !== newIds || JSON.stringify(prev.map((p:any)=>p.config)) !== JSON.stringify(cams.map((c:any)=>c.config))) {
             return cams;
          }
          return prev;
        });
      }
    } catch (err) {}
  };

  const fetchData = async () => {
    const token = localStorage.getItem('token');
    if (!token) return;
    try {
      const resEvents = await fetch(`/api/v1/events?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
      if (resEvents.ok) {
        const data = await resEvents.json();
        const evts = data.data || [];
        setAllEvents(evts); 
        
        const startOfToday = new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate()).getTime();
        setTodaysEvents(evts.filter((e: any) => {
          const ts = new Date(e.timestamp.endsWith('Z') ? e.timestamp : e.timestamp + 'Z').getTime();
          const isHeartbeat = String(e.event_name || '').toLowerCase() === 'heartbeat' || String(e.description || '').toLowerCase().includes('node1_alive');
          return ts >= startOfToday && !isHeartbeat;
        }));
        
        const sensorEvt = evts.find((e: any) => e.event_type === 'sensor');
        if (sensorEvt) {
          const match = sensorEvt.description.match(/\[Gas:([^\/\]]+)\/([^\]]+)\]/i);
          if (match) {
            setLatestMq3(parseInt(match[1]) || 0);
            setLatestMq2(parseInt(match[2]) || 0);
          }
        }
      }

      const resLora = await fetch(`/api/v1/lorawan/latest?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
      if (resLora.ok) {
        const loraData = await resLora.json();
        if (loraData?.status === 'success') {
          setLoraLatest(loraData);
          // UI display fix:
          // Current Node payload order is displayed reversed on dashboard, so swap here.
          const mq2 = parseInt(loraData?.parsed?.mq3 ?? '0') || 0;
          const mq3 = parseInt(loraData?.parsed?.mq2 ?? '0') || 0;
          setLatestMq2(mq2);
          setLatestMq3(mq3);
        }
      }

      const resAnalysis = await fetch(`/api/v1/analysis/current?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
      if (resAnalysis.ok) {
        const data = await resAnalysis.json();
        setAiState(data.state || 'safe');
      }
    } catch (err) {}
  };

  useEffect(() => {
    const currentBaseline = parseInt(localStorage.getItem('aegis_mq2_baseline') || '0');
    setMq2Baseline(currentBaseline);
    setBaselineInput(currentBaseline.toString());
    
    fetchUserAndCameras();
    fetchData();
    
    const intervalData = setInterval(fetchData, 2000); 
    const intervalCams = setInterval(fetchUserAndCameras, 3000);
    const intervalImg = setInterval(() => setRefreshKey(Date.now()), 500);
    
    return () => {
      clearInterval(intervalData);
      clearInterval(intervalCams);
      clearInterval(intervalImg);
    };
  }, [currentUser]);

  const handleResetSafety = async () => {
    const token = localStorage.getItem('token');
    try {
      const res = await fetch('/api/v1/events/reset', { method: 'POST', headers: { 'Authorization': `Bearer ${token}` } });
      if (res.ok) { 
        setLastSafeTime(Date.now());
        setAiState('safe');
        toast.success(lang === 'en' ? "Alert manually resolved!" : "人工確認安全，警報已解除！", { style: { background: '#10b981', color: '#fff', fontWeight: 'bold' }});
        fetchData(); 
      }
    } catch (err) {}
  };

  const sortedEvents = [...allEvents].sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
  const newestEventTime = sortedEvents.length > 0 ? new Date(sortedEvents[0].timestamp.endsWith('Z') ? sortedEvents[0].timestamp : sortedEvents[0].timestamp + 'Z').getTime() : 0;
  const isAllAcknowledged = (lastSafeTime > 0) && (newestEventTime <= lastSafeTime);

  const latestNanoEvent = allEvents.find(e => e.device_id === 'NANO-001' || e.device_id === 'DEV-NANO-001' || e.event_type === 'ai_vision' || e.event_type === 'system_heartbeat');
  const isNanoOnline = deviceStatuses['NANO-001'] === 'online' || cameras.length > 0 || !!(latestNanoEvent && (Math.abs(now - new Date(latestNanoEvent.timestamp.endsWith('Z') ? latestNanoEvent.timestamp : latestNanoEvent.timestamp+'Z').getTime()) < 2 * 60 * 1000));

  const loraLatestTime = loraLatest?.received_at ? new Date(loraLatest.received_at).getTime() : 0;
  const isLoraOnline = deviceStatuses['LORA-001'] === 'online' || !!(loraLatestTime && Math.abs(now - loraLatestTime) < 2 * 60 * 1000);

  const latestSosEvent = allEvents.find(e => e.event_type === 'voice_sos');
  const latestSosTime = latestSosEvent ? new Date(latestSosEvent.timestamp.endsWith('Z') ? latestSosEvent.timestamp : latestSosEvent.timestamp+'Z').getTime() : 0;

  const calibratedMq2 = Math.max(0, latestMq2 - mq2Baseline);
  const effectiveAiState = isAllAcknowledged ? 'safe' : aiState;
  const effectiveMq2High = isAllAcknowledged ? false : (calibratedMq2 > 400); 
  const effectiveSosActive = isAllAcknowledged ? false : !!(latestSosEvent && (Math.abs(now - latestSosTime) < 2 * 60 * 1000));

  const isSystemOffline = !isNanoOnline && !isLoraOnline;
  const isCritical = effectiveAiState === 'critical' || effectiveSosActive;
  const isWarning = effectiveAiState === 'warning' || effectiveMq2High;

  // 🌟 核心資安過濾：只顯示目前登入者有權限看的鏡頭
  const isAdmin = currentUser?.role === 'admin';
  const visibleCameras = cameras.filter(cam => {
    if (isAdmin) return true;
    const assignees = cam.config?.assignees || ['admin'];
    return assignees.includes(currentUser?.username) || assignees.includes(currentUser?.id?.toString());
  });

  let aiSummaryText = "";
  if (isSystemOffline) {
    aiSummaryText = lang === 'en' ? "System disconnected. Waiting for edge devices to come online." : "系統已斷線。等待邊緣設備重新連線中。";
  } else if (effectiveSosActive) {
    aiSummaryText = lang === 'en' ? "🚨 CRITICAL: Human voice SOS detected! Immediate action required!" : "🚨 危險：偵測到人類 SOS 語音呼救！請立即採取行動！";
  } else if (effectiveAiState === 'critical') {
    aiSummaryText = lang === 'en' ? "🚨 CRITICAL: AI vision system has flagged recent suspicious physical activity." : "🚨 危險：AI 視覺系統標記了近期的異常物理活動。";
  } else if (effectiveMq2High) {
    aiSummaryText = lang === 'en' 
      ? `⚠️ WARNING: High gas levels (${calibratedMq2} ppm), but Vision Node shows no anomalies.` 
      : `⚠️ 警告：偵測到高濃度氣體 (${calibratedMq2} ppm)，請留意。`;
  } else if (isAllAcknowledged) {
    aiSummaryText = lang === 'en' ? "✅ Threats have been manually verified as safe." : "✅ 上述危險已人工確認是安全的。系統已恢復正常監控。";
  } else {
    aiSummaryText = lang === 'en' ? "✅ Environment is stable. Visual feed normal, sensors show clean air." : "✅ 環境目前穩定。影像畫面正常，感測器數據良好。未偵測到立即威脅。";
  }

  const handleSaveCalibration = () => {
    const val = parseInt(baselineInput);
    if (isNaN(val) || val < 0) return;
    localStorage.setItem('aegis_mq2_baseline', val.toString());
    setMq2Baseline(val);
    toast.success(lang === 'en' ? `Baseline updated to ${val} ppm` : `基準值已更新為 ${val} ppm`, { style: { background: '#172033', color: '#fff' }});
    setShowCalibrateModal(false);
  };

  if (!isClient) return <div className="p-8 text-indigo-400 font-mono animate-pulse">載入中...</div>;

  return (
    <div className="p-8 max-w-[1600px] mx-auto space-y-6 animate-in fade-in duration-500 relative">
      <div className={`bg-[#131B2C] border ${isCritical ? 'border-red-500/50 shadow-red-500/10' : isWarning ? 'border-orange-500/50 shadow-orange-500/10' : 'border-[#2A3750] shadow-black/20'} rounded-2xl p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-5 shadow-lg transition-colors duration-500`}>
        <div className="flex items-center gap-5">
          <div className={`p-3 rounded-xl border ${isCritical ? 'bg-red-500/10 border-red-500/20' : isWarning ? 'bg-orange-500/10 border-orange-500/20' : 'bg-indigo-500/10 border-indigo-500/20'}`}>
            <BrainCircuit className={`w-7 h-7 ${isCritical ? 'text-red-400 animate-pulse' : isWarning ? 'text-orange-400 animate-pulse' : 'text-indigo-400'}`} />
          </div>
          <div>
            <div className="flex items-center gap-3 mb-1.5">
              <h2 className="text-white font-bold text-lg tracking-wide">{lang === 'en' ? 'AI Automated Analysis' : 'AI 自動分析引擎'}</h2>
              <span className={`text-[10px] font-black px-2 py-0.5 rounded uppercase tracking-wider ${isCritical ? 'bg-red-500/20 text-red-300' : isWarning ? 'bg-orange-500/20 text-orange-300' : 'bg-indigo-500/20 text-indigo-300'}`}>
                {isCritical ? (lang === 'en' ? 'ALERTING' : '警報中') : isWarning ? (lang === 'en' ? 'WARNING' : '警告中') : (lang === 'en' ? 'ACTIVE' : '運作中')}
              </span>
            </div>
            <p className={`text-sm font-mono leading-relaxed ${isCritical ? 'text-red-400 font-bold' : isWarning ? 'text-orange-400 font-bold' : isAllAcknowledged ? 'text-emerald-400' : 'text-gray-400'}`}>
              {aiSummaryText}
            </p>
          </div>
        </div>
        {(aiState !== 'safe' || calibratedMq2 > 400 || effectiveSosActive) && !isAllAcknowledged && (
          <button onClick={handleResetSafety} className="w-full sm:w-auto px-6 py-3 bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/30 text-emerald-400 rounded-xl text-sm font-bold flex items-center justify-center transition-all shadow-[0_0_15px_rgba(16,185,129,0.15)] group">
            <CheckCircle className="w-5 h-5 mr-2 group-hover:scale-110 transition-transform" /> {lang === 'en' ? 'Mark as Safe' : '人工確認安全'}
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.25rem] p-6 shadow-xl relative overflow-hidden">
          <div className="flex justify-between items-start mb-6">
            <div className="text-gray-400 text-sm font-medium leading-tight">{lang === 'en' ? 'Vision Node' : '影像辨識節點'}<br/>(Nano)</div>
            <div className={`p-2.5 rounded-xl ${isNanoOnline ? 'bg-indigo-500/20' : 'bg-[#1E293B]'}`}><Cpu className={`w-5 h-5 ${isNanoOnline ? 'text-indigo-400' : 'text-gray-400'}`} /></div>
          </div>
          <div className={`text-2xl font-black tracking-wide ${isNanoOnline ? 'text-indigo-400' : 'text-gray-500'}`}>{isNanoOnline ? (lang === 'en' ? 'ONLINE' : '連線中') : (lang === 'en' ? 'OFFLINE' : '離線')}</div>
        </div>

        <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.25rem] p-6 shadow-xl relative overflow-hidden">
          <div className="flex justify-between items-start mb-6">
            <div className="text-gray-400 text-sm font-medium leading-tight">{lang === 'en' ? 'Gateway' : '傳感網關'}<br/>(LoRa)</div>
            <div className={`p-2.5 rounded-xl ${isLoraOnline ? 'bg-emerald-500/20' : 'bg-[#1E293B]'}`}><Radio className={`w-5 h-5 ${isLoraOnline ? 'text-emerald-400' : 'text-gray-400'}`} /></div>
          </div>
          <div className={`text-2xl font-black tracking-wide ${isLoraOnline ? 'text-emerald-400' : 'text-gray-500'}`}>{isLoraOnline ? (lang === 'en' ? 'ONLINE' : '連線中') : (lang === 'en' ? 'OFFLINE' : '離線')}</div>
        </div>

        <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.25rem] p-6 shadow-xl relative overflow-hidden">
          <div className="flex justify-between items-start mb-6">
            <div className="text-gray-400 text-sm font-medium leading-tight">{lang === 'en' ? 'Today\'s Events' : '今日事件數'}<br/>(Today)</div>
            <div className="bg-blue-500/10 p-2.5 rounded-xl"><FileText className="w-5 h-5 text-blue-400" /></div>
          </div>
          <div className="text-4xl font-black text-white tracking-tight">{todaysEvents.length}</div>
        </div>

        <div className={`bg-[#131B2C] border rounded-[1.25rem] p-6 shadow-xl relative overflow-hidden transition-colors ${isSystemOffline ? 'border-[#1E293B]' : isCritical ? 'border-red-500/50' : isWarning ? 'border-orange-500/50' : 'border-[#1E293B]'}`}>
          {!isSystemOffline && isCritical && <div className="absolute inset-0 bg-red-500/5 animate-pulse"></div>}
          <div className="flex justify-between items-start mb-6 relative z-10">
            <div className="text-gray-400 text-sm font-medium leading-tight">{lang === 'en' ? 'Site Safety' : '場域安全'}<br/>Status</div>
            <div className={`p-2.5 rounded-xl ${isSystemOffline ? 'bg-gray-800' : isCritical ? 'bg-red-500/20' : isWarning ? 'bg-orange-500/20' : 'bg-emerald-500/10'}`}>
              <Activity className={`w-5 h-5 ${isSystemOffline ? 'text-gray-500' : isCritical ? 'text-red-400' : isWarning ? 'text-orange-400' : 'text-emerald-400'}`} />
            </div>
          </div>
          <div className={`text-2xl font-black tracking-wide relative z-10 ${isSystemOffline ? 'text-gray-500' : isCritical ? 'text-red-400' : isWarning ? 'text-orange-400' : 'text-emerald-400'}`}>
            {isSystemOffline ? (lang === 'en' ? 'OFFLINE' : '離線') : isCritical ? (lang === 'en' ? 'CRITICAL' : '危險') : isWarning ? (lang === 'en' ? 'WARNING' : '警告') : (lang === 'en' ? 'SAFE' : '安全')}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] p-6 shadow-2xl flex flex-col min-h-[550px]">
          <div className="flex justify-between items-center mb-5">
            <h3 className="text-white font-bold text-lg flex items-center gap-3"><Video className="w-5 h-5 text-gray-400" /> {lang === 'en' ? 'Live AI Camera' : 'AI 即時影像'}</h3>
            <div className="flex items-center gap-2">
              <div className={`w-2 h-2 rounded-full ${visibleCameras.length > 0 ? 'bg-red-500 animate-pulse' : 'bg-gray-600'}`}></div>
              <span className="text-xs font-bold text-gray-400 tracking-widest uppercase">{visibleCameras.length > 0 ? 'LIVE' : 'NO FEED'}</span>
            </div>
          </div>
          
          <div className="flex-1 bg-[#0B0F19] border border-[#1E293B] rounded-2xl shadow-inner relative overflow-hidden shadow-black/50">
            {/* 🌟 權限過濾渲染區 */}
            {visibleCameras.length === 0 ? (
              <div className="absolute inset-0 bg-black flex flex-col items-center justify-center animate-in fade-in duration-500">
                <div className="bg-[#111111] border border-red-500/30 px-8 py-6 rounded-3xl flex flex-col items-center shadow-2xl backdrop-blur-sm">
                  <AlertTriangle className="w-14 h-14 text-red-500 mb-3 animate-pulse opacity-90" />
                  <span className="text-red-400 font-black tracking-[0.1em] text-xl mb-1">{lang === 'en' ? 'ACCESS DENIED / OFFLINE' : '無觀看權限或已離線'}</span>
                  <span className="text-gray-500 text-sm font-mono tracking-wide">{lang === 'en' ? 'No video feed available' : '目前無可顯示的影像訊號'}</span>
                </div>
              </div>
            ) : (
              <div className={`absolute inset-0 p-4 grid gap-4 ${visibleCameras.length === 1 ? 'grid-cols-1' : 'grid-cols-1 sm:grid-cols-2'}`}>
                {visibleCameras.map(cam => (
                  <div key={cam.id} className="relative bg-black rounded-xl border border-[#1E293B] overflow-hidden group">
                    <div className="absolute top-3 left-3 z-10">
                      <span className="bg-emerald-500/20 border border-emerald-500/50 text-emerald-400 text-[10px] font-bold px-2.5 py-1.5 rounded-full flex items-center backdrop-blur-md shadow-lg">
                        <span className="w-1.5 h-1.5 bg-emerald-400 rounded-full mr-1.5 animate-pulse"></span> {cam.name}
                      </span>
                    </div>
                    {/* 🌟 7大 AI 模型動態圖示 (浮點數 > 0 代表開啟) */}
                    <div className="absolute top-3 right-3 z-10 flex flex-wrap justify-end gap-1.5 shadow-lg max-w-[70%]">
                      {cam.config?.fire > 0 && <Flame className="w-5 h-5 text-rose-500 bg-black/60 border border-rose-500/30 p-1 rounded-md backdrop-blur-md" />}
                      {cam.config?.smoke > 0 && <Wind className="w-5 h-5 text-amber-500 bg-black/60 border border-amber-500/30 p-1 rounded-md backdrop-blur-md" />}
                      {cam.config?.fall > 0 && <UserX className="w-5 h-5 text-indigo-500 bg-black/60 border border-indigo-500/30 p-1 rounded-md backdrop-blur-md" />}
                      {cam.config?.hardhat > 0 && <HardHat className="w-5 h-5 text-yellow-500 bg-black/60 border border-yellow-500/30 p-1 rounded-md backdrop-blur-md" />}
                      {cam.config?.vest > 0 && <Shirt className="w-5 h-5 text-orange-500 bg-black/60 border border-orange-500/30 p-1 rounded-md backdrop-blur-md" />}
                      {cam.config?.smoking > 0 && <Cigarette className="w-5 h-5 text-red-500 bg-black/60 border border-red-500/30 p-1 rounded-md backdrop-blur-md" />}
                      {cam.config?.phone > 0 && <Smartphone className="w-5 h-5 text-blue-500 bg-black/60 border border-blue-500/30 p-1 rounded-md backdrop-blur-md" />}
                    </div>
                    <img 
                      src={`${cam.stream_url}?t=${refreshKey}`} 
                      alt={cam.name} 
                      className="w-full h-full object-contain transition-opacity duration-200"
                      onError={(e) => { e.currentTarget.style.opacity = '0.1'; }}
                      onLoad={(e) => { e.currentTarget.style.opacity = '1'; }}
                    />
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] p-6 shadow-2xl flex flex-col min-h-[550px]">
          <h3 className="text-white font-bold text-lg flex items-start gap-3 mb-6 leading-tight"><Activity className="w-5 h-5 text-indigo-400 mt-0.5" /> {lang === 'en' ? 'Sensor' : '感測器'}<br/>{lang === 'en' ? 'Telemetry' : '遙測數據'}</h3>
          <div className="space-y-4 flex-1">
            <div className="bg-[#0B0F19] border border-[#1E293B] rounded-2xl p-5 shadow-inner transition-all hover:border-[#2A3750]">
              <div className="flex justify-between items-start mb-2">
                <div className="text-gray-400 text-sm font-medium leading-snug">{lang === 'en' ? 'Smoke / Gas' : '煙霧 / 氣體'}<br/>(MQ2)</div>
                <div className="flex items-center gap-2">
                  <button onClick={() => setShowCalibrateModal(true)} className="p-1.5 hover:bg-[#1E293B] rounded-lg transition-colors cursor-pointer outline-none border-none group">
                    <SlidersHorizontal className="w-4 h-4 text-gray-500 group-hover:text-indigo-400 transition-colors" />
                  </button>
                  {effectiveMq2High ? (
                    <span className="bg-orange-500/20 text-orange-400 text-[10px] font-black px-2 py-1 rounded tracking-wider">{lang === 'en' ? 'WARNING' : '警告'}</span>
                  ) : (
                    <span className="bg-emerald-500/20 text-emerald-400 text-[10px] font-black px-2 py-1 rounded tracking-wider">{lang === 'en' ? 'NORMAL' : '正常'}</span>
                  )}
                </div>
              </div>
              <div className="flex items-baseline gap-2 mt-6">
                <span className={`text-4xl font-black ${effectiveMq2High ? 'text-orange-400' : 'text-white'}`}>{calibratedMq2}</span>
                <span className="text-gray-500 text-sm font-medium">ppm</span>
              </div>
            </div>

            <div className="bg-[#0B0F19] border border-[#1E293B] rounded-2xl p-5 shadow-inner">
              <div className="flex justify-between items-start mb-2">
                <div className="text-gray-400 text-sm font-medium leading-snug">{lang === 'en' ? 'Alcohol' : '酒精'}<br/>(MQ3)</div>
                <span className="bg-emerald-500/20 text-emerald-400 text-[10px] font-black px-2 py-1 rounded tracking-wider">{lang === 'en' ? 'NORMAL' : '正常'}</span>
              </div>
              <div className="flex items-baseline gap-2 mt-6">
                <span className="text-3xl font-black text-white">{latestMq3}</span>
                <span className="text-gray-500 text-sm font-medium">ppm</span>
              </div>
            </div>
          </div>
          <button onClick={() => setShowTimelineModal(true)} className="w-full mt-6 bg-indigo-500/10 hover:bg-indigo-500/20 text-indigo-400 border border-indigo-500/20 rounded-xl py-3.5 flex items-center justify-center gap-2 font-bold transition-all shadow-lg outline-none">
            <History className="w-4 h-4" /> {lang === 'en' ? 'View Today\'s Audit Timeline' : '查看今日所有歷史時間軸'}
          </button>
        </div>
      </div>
      
      {/* 彈出視窗保持不變... */}
      {showCalibrateModal && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-sm px-4 animate-in fade-in duration-200">
           <div className="bg-[#131B2C] border border-[#2A3750] p-7 rounded-[2rem] shadow-2xl w-full max-w-sm">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-white text-xl font-black tracking-wide">{lang === 'en' ? 'Sensor Calibration' : '感測器基準校準'}</h3>
              <button onClick={() => setShowCalibrateModal(false)} className="text-gray-500 hover:text-white transition-colors"><X className="w-5 h-5" /></button>
            </div>
            <p className="text-gray-400 text-sm mb-6 leading-relaxed">
              {lang === 'en' ? 'Set a baseline to filter out background noise from the sensor.' : '設定環境基準值 (Baseline)，系統將自動過濾背景雜訊。'}
            </p>
            <div className="mb-8">
              <label className="block text-xs font-bold text-gray-500 uppercase tracking-widest mb-2">Current Baseline (ppm)</label>
              <input
                type="number"
                value={baselineInput}
                onChange={(e) => setBaselineInput(e.target.value)}
                className="w-full bg-[#0B0F19] border border-[#2A3750] rounded-xl px-4 py-3 text-white text-lg font-mono focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all"
              />
            </div>
            <div className="flex justify-end gap-3">
              <button onClick={() => setShowCalibrateModal(false)} className="px-5 py-2.5 rounded-xl text-gray-400 font-medium hover:text-white hover:bg-[#1E293B] transition-colors">
                {lang === 'en' ? 'Cancel' : '取消'}
              </button>
              <button onClick={handleSaveCalibration} className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold transition-colors shadow-lg shadow-indigo-500/25">
                {lang === 'en' ? 'Save' : '儲存校準'}
              </button>
            </div>
          </div>
        </div>
      )}

      {showTimelineModal && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-sm px-4 animate-in fade-in zoom-in-95 duration-200">
           <div className="bg-[#131B2C] border border-[#2A3750] rounded-[2rem] shadow-2xl w-full max-w-2xl flex flex-col max-h-[80vh]">
            <div className="p-6 border-b border-[#1E293B] flex justify-between items-center bg-[#172033] rounded-t-[2rem]">
              <h3 className="text-white text-xl font-black flex items-center gap-3">
                <History className="w-6 h-6 text-indigo-400" />
                {lang === 'en' ? 'Today\'s Audit Timeline' : '今日事件時間軸'}
                <span className="text-sm font-medium text-gray-400 ml-2 bg-[#0B0F19] px-2 py-1 rounded-md border border-[#2A3750]">
                  {todaysEvents.length} {lang === 'en' ? 'events' : '筆事件'}
                </span>
              </h3>
              <button onClick={() => setShowTimelineModal(false)} className="text-gray-500 hover:text-white transition-colors bg-[#0B0F19] p-2 rounded-xl border border-[#2A3750]"><X className="w-5 h-5" /></button>
            </div>
            
            <div className="p-6 overflow-y-auto custom-scrollbar flex-1 space-y-6 bg-[#0B0F19]">
              {todaysEvents.length === 0 ? (
                <div className="text-center text-gray-500 font-mono py-10">
                  {lang === 'en' ? 'No events found for today.' : '今日無任何事件記錄。'}
                </div>
              ) : (
                <div className="relative border-l-2 border-[#1E293B] ml-3 space-y-8">
                  {todaysEvents.map((evt, idx) => (
                    <div key={idx} className="relative pl-6">
                      <div className={`absolute -left-[9px] top-1 w-4 h-4 rounded-full border-2 border-[#0B0F19] ${evt.severity === 'critical' ? 'bg-red-500' : evt.severity === 'high' ? 'bg-orange-500' : 'bg-blue-500'}`}></div>
                      <div className="bg-[#131B2C] border border-[#1E293B] p-4 rounded-xl shadow-md">
                        <div className="flex justify-between items-start mb-2">
                          <span className="text-white font-bold">{evt.event_name}</span>
                          <span className="text-xs text-gray-500 font-mono">{new Date(evt.timestamp.endsWith('Z') ? evt.timestamp : evt.timestamp + 'Z').toLocaleTimeString()}</span>
                        </div>
                        <p className="text-gray-400 text-sm">{evt.description || (lang === 'en' ? 'No description provided.' : '無詳細描述。')}</p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
