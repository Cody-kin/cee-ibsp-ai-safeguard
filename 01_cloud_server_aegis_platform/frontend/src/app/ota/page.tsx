'use client';
import { useState, useEffect, useRef } from 'react';
import { CloudUpload, FileCode2, Trash2, HardDrive, RefreshCw, AlertTriangle, ShieldCheck, CheckSquare, Square, PlayCircle, X, Terminal, PauseCircle, Loader2, Unlock, History, CheckCircle2, XCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { useLangStore } from '@/store/langStore';

export default function OTAPage() {
  const { lang } = useLangStore();
  const [files, setFiles] = useState<any[]>([]);
  const [selectedFiles, setSelectedFiles] = useState<string[]>([]);
  const [isDragging, setIsDragging] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);
  
  const [showDeployModal, setShowDeployModal] = useState(false);
  const [scriptContent, setScriptContent] = useState<string>('');
  const [isDeploying, setIsDeploying] = useState(false);
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [otaFinishTime, setOtaFinishTime] = useState<string>('');
  
  const [historyLogs, setHistoryLogs] = useState<any[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // 🌟 雲端讀取法 (Web 和 iOS 共用這個來源)
  const fetchHistoryLogs = async () => {
    try {
      const res = await fetch(`/ota-api/logs?_t=${Date.now()}`);
      if (res.ok) setHistoryLogs(await res.json());
    } catch(e) {}
  };

  const addHistoryLog = async (status: string, message: string) => {
    try {
      await fetch('/ota-api/logs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status, message })
      });
      fetchHistoryLogs(); // 寫完立刻刷新
    } catch(e) {}
  };

  const clearHistoryLogs = async () => {
    if (!window.confirm(lang === 'en' ? 'Clear all update history?' : '確定要清空所有的歷史更新紀錄嗎？')) return;
    try {
      await fetch('/ota-api/logs', { method: 'DELETE' });
      setHistoryLogs([]);
      toast.success(lang === 'en' ? 'History cleared' : '日誌已清空');
    } catch(e) {}
  };

  useEffect(() => {
    const status = localStorage.getItem('ota_status');
    if (status === 'updating') setIsDeploying(true);
    else if (status === 'done') {
      setShowSuccessModal(true);
      setOtaFinishTime(localStorage.getItem('ota_finish_time') || '');
    }
    fetchHistoryLogs(); // 載入時抓取雲端日誌
  }, []);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isDeploying) {
      interval = setInterval(async () => {
        try {
          const token = localStorage.getItem('token');
          const res = await fetch(`/api/v1/events?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
          if (res.ok) {
            const data = await res.json();
            const events = Array.isArray(data) ? data : (data.data || []);
            const baselineLogId = localStorage.getItem('ota_baseline_log') || "";
            const sysLogs = events.filter((e: any) => e.event_type === 'system_log' || e.event_type === 'sys_log');
            
            let triggeredEvent = null;
            for (const log of sysLogs) {
              const currentLogId = `${log.timestamp}_${log.description}`;
              if (currentLogId === baselineLogId) break; 
              
              const isSuccess = log.event_name === 'OTA Success' || log.event_name === 'System Ready' || (log.description && log.description.includes('AI-SafeGuard Started Successfully'));
              const isError = log.event_name === 'OTA Error';
              
              if (isSuccess || isError) {
                triggeredEvent = log;
                break;
              }
            }

            if (triggeredEvent) {
              clearInterval(interval);
              const isErrorLog = triggeredEvent.event_name === 'OTA Error';
              
              if (!isErrorLog) {
                const finishTime = new Date().toLocaleTimeString();
                localStorage.setItem('ota_status', 'done');
                localStorage.setItem('ota_finish_time', finishTime);
                setIsDeploying(false);
                setOtaFinishTime(finishTime);
                setShowSuccessModal(true);
                addHistoryLog('Success', lang === 'en' ? 'Edge device updated successfully' : '邊緣設備更新與重啟成功');
              } else {
                localStorage.removeItem('ota_status');
                localStorage.removeItem('ota_baseline_log');
                setIsDeploying(false);
                toast.error(lang === 'en' ? `OTA Failed: ${triggeredEvent.description}` : `設備更新失敗：${triggeredEvent.description}`);
                addHistoryLog('Failed', triggeredEvent.description || 'Unknown Error');
              }
            }
          }
        } catch (err) {}
      }, 3000);
    }
    return () => clearInterval(interval);
  }, [isDeploying]);

  const fetchFiles = async () => {
    const token = localStorage.getItem('token');
    if (!token) return;
    try {
      if (isCheckingAuth) {
        const userRes = await fetch(`/api/v1/users/me?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (userRes.ok) {
          const userData = await userRes.json();
          setIsAdmin(userData.role === 'admin');
        }
        setIsCheckingAuth(false);
      }
      const res = await fetch(`/api/v1/ota/files?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
      if (res.ok) {
        const data = await res.json();
        setFiles(data.data || []);
      }
    } catch (err) {}
  };

  useEffect(() => { fetchFiles(); }, []);

  const formatSize = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const handleUpload = async (uploadFiles: FileList) => {
    if (!isAdmin) return;
    setIsUploading(true);
    const token = localStorage.getItem('token');
    for (let i = 0; i < uploadFiles.length; i++) {
      const file = uploadFiles[i];
      const toastId = toast.loading(lang === 'en' ? `Uploading ${file.name}...` : `正在上傳 ${file.name}...`);
      const formData = new FormData();
      formData.append('file', file);
      try {
        const res = await fetch('/api/v1/ota/upload', { method: 'POST', headers: { 'Authorization': `Bearer ${token}` }, body: formData });
        if (res.ok) {
            toast.success(lang === 'en' ? `${file.name} uploaded!` : `${file.name} 上傳成功！`, { id: toastId, style: { background: '#10b981', color: '#fff' }});
            if (file.name === 'update.sh' || file.name.endsWith('.pt')) {
                addHistoryLog('Info', `上傳了新載荷: ${file.name}`);
            }
        }
        else toast.error(lang === 'en' ? 'Upload failed' : '上傳失敗', { id: toastId });
      } catch (err) { toast.error('Network Error', { id: toastId }); }
    }
    setIsUploading(false);
    fetchFiles();
  };

  const toggleSelect = (filename: string) => { setSelectedFiles(prev => prev.includes(filename) ? prev.filter(f => f !== filename) : [...prev, filename]); };
  const toggleSelectAll = () => { if (selectedFiles.length === files.length) setSelectedFiles([]); else setSelectedFiles(files.map(f => f.name)); };

  const handleDeleteSelected = async () => {
    if (selectedFiles.length === 0 || !window.confirm(lang === 'en' ? `Delete ${selectedFiles.length} files?` : `確定要刪除選中的 ${selectedFiles.length} 個檔案嗎？`)) return;
    const token = localStorage.getItem('token');
    for (const filename of selectedFiles) { await fetch(`/api/v1/ota/files/${filename}`, { method: 'DELETE', headers: { 'Authorization': `Bearer ${token}` } }); }
    toast.success(lang === 'en' ? 'Files deleted' : '檔案已刪除');
    setSelectedFiles([]);
    fetchFiles();
  };

  const handleClearAll = async () => {
    if (!window.confirm(lang === 'en' ? 'Are you sure you want to CLEAR ALL files?' : '危險操作：確定要清空伺服器上所有的 OTA 檔案嗎？')) return;
    const token = localStorage.getItem('token');
    await fetch(`/api/v1/ota/files`, { method: 'DELETE', headers: { 'Authorization': `Bearer ${token}` } });
    toast.success(lang === 'en' ? 'All files cleared' : '所有檔案已清空');
    setSelectedFiles([]);
    fetchFiles();
  };

  const handlePreviewDeploy = async () => {
    const hasScript = files.some(f => f.name === 'update.sh');
    if (!hasScript) { toast.error(lang === 'en' ? 'Missing update.sh. The device needs a script to execute.' : '找不到 update.sh！設備需要這個腳本才知道要做什麼。'); return; }
    const token = localStorage.getItem('token');
    try {
      const res = await fetch(`/api/v1/ota/files/update.sh/content`, { headers: { 'Authorization': `Bearer ${token}` } });
      if (res.ok) {
        const data = await res.json();
        setScriptContent(data.content);
        setShowDeployModal(true);
      }
    } catch (err) { toast.error(lang === 'en' ? 'Failed to read script' : '無法讀取腳本內容'); }
  };

  const executeDeployment = async () => {
    const token = localStorage.getItem('token');
    try {
      let baselineStr = "";
      try {
        const evRes = await fetch(`/api/v1/events?_t=${Date.now()}`, { headers: { 'Authorization': `Bearer ${token}` } });
        if (evRes.ok) {
          const evData = await evRes.json();
          const evList = Array.isArray(evData) ? evData : (evData.data || []);
          const firstSysLog = evList.find((e: any) => e.event_type === 'system_log' || e.event_type === 'sys_log');
          if (firstSysLog) {
            baselineStr = `${firstSysLog.timestamp}_${firstSysLog.description}`;
          }
        }
      } catch(e) {}

      const res = await fetch('/api/v1/devices/NANO-001/system_command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ command: 'OTA_SCRIPT' })
      });
      if (res.ok) {
        toast.success(lang === 'en' ? 'Deployment command dispatched via LoRa!' : '部署指令已透過 LoRa 下發！', { icon: '🚀', style: { background: '#10b981', color: '#fff' }});
        
        localStorage.setItem('ota_status', 'updating');
        localStorage.setItem('ota_baseline_log', baselineStr);
        setIsDeploying(true);
        setShowDeployModal(false);
        
        addHistoryLog('Deploying', lang === 'en' ? 'OTA command dispatched via LoRa' : '已透過 LoRa 頻段下發 OTA 升級指令');
      }
    } catch (err) {
      toast.error(lang === 'en' ? 'Failed to dispatch command' : '指令下發失敗');
    }
  };

  const handleSuccessConfirm = () => {
    localStorage.removeItem('ota_status');
    localStorage.removeItem('ota_baseline_log');
    localStorage.removeItem('ota_finish_time');
    setShowSuccessModal(false);
  };

  const handleEmergencyUnlock = () => {
    localStorage.removeItem('ota_status');
    localStorage.removeItem('ota_baseline_log');
    localStorage.removeItem('ota_finish_time');
    setIsDeploying(false);
    toast.error(lang === 'en' ? 'UI Lock Released. Please check device manually.' : '已強制解除 UI 鎖定，請確認設備狀態。', { icon: '🔓', style: { background: '#333', color: '#fff' }});
    addHistoryLog('Failed', lang === 'en' ? 'Manually unlocked by Admin' : '管理員強制中止了等待程序');
  };

  const handleDragOver = (e: React.DragEvent) => { e.preventDefault(); setIsDragging(true); };
  const handleDragLeave = () => setIsDragging(false);
  const handleDrop = (e: React.DragEvent) => { e.preventDefault(); setIsDragging(false); if (e.dataTransfer.files) handleUpload(e.dataTransfer.files); };

  if (isCheckingAuth) return <div className="p-8 text-indigo-400 font-mono animate-pulse">Loading...</div>;

  if (!isAdmin) {
    return (
      <div className="p-8 flex flex-col items-center justify-center h-[80vh]">
        <AlertTriangle className="w-20 h-20 text-red-500/50 mb-4" />
        <h2 className="text-2xl font-bold text-white mb-2">{lang === 'en' ? 'Access Denied' : '權限不足'}</h2>
        <p className="text-gray-400 text-center">{lang === 'en' ? 'OTA updates require Administrator privileges.' : 'OTA 遠端升級功能屬於核心操作，僅限 Admin 管理員身分存取。'}</p>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[1400px] mx-auto space-y-8 animate-in fade-in pb-20">
      <div className="flex justify-between items-end border-b border-[#1E293B] pb-6">
        <div>
          <h1 className="text-3xl font-black text-white flex items-center"><CloudUpload className="w-8 h-8 mr-4 text-blue-400" /> {lang === 'en' ? 'OTA Payload Center' : 'OTA 韌體與載荷中心'}</h1>
          <p className="text-gray-400 mt-2 text-sm font-medium">{lang === 'en' ? 'Upload AI models and scripts. Review code before deployment.' : '上傳 AI 模型與腳本。在部署前，您將被要求檢閱將執行的程式碼。'}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-6">
          <div 
            onDragOver={handleDragOver} onDragLeave={handleDragLeave} onDrop={handleDrop} onClick={() => fileInputRef.current?.click()}
            className={`bg-[#131B2C] border-2 border-dashed rounded-3xl p-10 flex flex-col items-center justify-center text-center transition-all duration-300 h-[300px] ${isDeploying ? 'opacity-50 cursor-not-allowed border-[#1E293B]' : 'cursor-pointer'} ${isDragging && !isDeploying ? 'border-blue-500 bg-blue-500/10' : 'border-[#2A3750] hover:border-blue-400/50 hover:bg-[#172033]'}`}
          >
            <input type="file" multiple ref={fileInputRef} className="hidden" disabled={isDeploying} onChange={(e) => { if (e.target.files) handleUpload(e.target.files); }} />
            <div className={`p-5 rounded-full mb-6 transition-colors ${isDragging ? 'bg-blue-500/20' : 'bg-[#1E293B]'}`}><CloudUpload className={`w-12 h-12 ${isDragging ? 'text-blue-400' : 'text-gray-400'}`} /></div>
            <h3 className="text-white font-bold text-xl mb-2">{lang === 'en' ? 'Click or Drag files here' : '點擊或拖曳檔案至此'}</h3>
            <p className="text-sm text-gray-500 font-mono leading-relaxed">{lang === 'en' ? 'Supports .pt, .sh, .zip' : '支援 .pt / .sh / .zip'}</p>
            {isUploading && <p className="mt-4 text-blue-400 font-bold animate-pulse">{lang === 'en' ? 'Uploading...' : '檔案傳輸中...'}</p>}
          </div>

          <div className="bg-[#131B2C] border border-[#1E293B] p-6 rounded-2xl">
            <h4 className="text-white font-bold mb-3 flex items-center"><ShieldCheck className="w-5 h-5 mr-2 text-emerald-400" /> {lang === 'en' ? 'Execution Safety Protocol' : '執行安全協議'}</h4>
            <ul className="text-sm text-gray-400 space-y-3 font-medium">
              <li className="flex items-start"><PauseCircle className="w-4 h-4 text-orange-400 mr-2 shrink-0 mt-0.5"/> {lang === 'en' ? 'Updates will PAUSE active AI inference.' : '更新指令下發後，設備將強制暫停目前的 AI 影像推理，以釋放記憶體。'}</li>
              <li className="flex items-start"><Terminal className="w-4 h-4 text-blue-400 mr-2 shrink-0 mt-0.5"/> {lang === 'en' ? 'The system reads and executes update.sh.' : '系統將下載並執行伺服器上的 update.sh 腳本。'}</li>
              <li className="flex items-start"><RefreshCw className="w-4 h-4 text-emerald-400 mr-2 shrink-0 mt-0.5"/> {lang === 'en' ? 'Auto-restart ensures clean application of new models.' : '腳本執行完畢後，進程會自動重啟 (Hot-reload) 載入新模型。'}</li>
            </ul>
          </div>
        </div>

        <div className="lg:col-span-2 bg-[#131B2C] border border-[#1E293B] rounded-[2rem] p-6 shadow-xl flex flex-col h-[650px]">
          <div className="flex justify-between items-center mb-6 px-2">
            <h3 className="text-white font-bold text-lg flex items-center"><HardDrive className="w-5 h-5 mr-2 text-gray-400" /> {lang === 'en' ? 'Payload Repository' : '雲端載荷庫'}</h3>
            <div className="flex gap-3">
              {selectedFiles.length > 0 && !isDeploying && (
                <button onClick={handleDeleteSelected} className="flex items-center gap-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 px-4 py-2 rounded-xl text-sm font-bold transition-colors">
                  <Trash2 className="w-4 h-4" /> {lang === 'en' ? `Delete (${selectedFiles.length})` : `刪除選中 (${selectedFiles.length})`}
                </button>
              )}
              <button disabled={isDeploying} onClick={handleClearAll} className="flex items-center gap-2 bg-[#1E293B] hover:bg-red-500/20 hover:text-red-400 text-gray-400 px-4 py-2 rounded-xl text-sm font-bold transition-colors disabled:opacity-50">
                {lang === 'en' ? 'Clear All' : '一鍵清空'}
              </button>
              <button onClick={fetchFiles} className="text-gray-400 hover:text-white transition-colors p-2.5 bg-[#0B0F19] rounded-xl border border-[#1E293B]"><RefreshCw className={`w-4 h-4 ${isDeploying ? 'animate-spin text-blue-400' : ''}`} /></button>
            </div>
          </div>

          <div className="flex-1 bg-[#0B0F19] border border-[#1E293B] rounded-2xl overflow-hidden flex flex-col mb-6">
            {files.length === 0 ? (
              <div className="flex-1 flex flex-col items-center justify-center text-gray-500"><FileCode2 className="w-12 h-12 mb-3 opacity-20" /><p>{lang === 'en' ? 'No files available' : '目前伺服器上沒有任何檔案'}</p></div>
            ) : (
              <div className="overflow-y-auto custom-scrollbar flex-1">
                <table className="w-full text-left text-sm">
                  <thead className="text-xs text-gray-500 uppercase tracking-widest sticky top-0 bg-[#0B0F19] z-10 shadow-sm">
                    <tr>
                      <th className="px-4 py-4 w-12 cursor-pointer" onClick={isDeploying ? undefined : toggleSelectAll}>
                        {selectedFiles.length === files.length && files.length > 0 ? <CheckSquare className="w-4 h-4 text-indigo-400" /> : <Square className="w-4 h-4 text-gray-500" />}
                      </th>
                      <th className="px-4 py-4 font-bold">{lang === 'en' ? 'Filename' : '檔案名稱'}</th>
                      <th className="px-4 py-4 font-bold">{lang === 'en' ? 'Size' : '大小'}</th>
                      <th className="px-4 py-4 font-bold">{lang === 'en' ? 'Modified' : '上傳時間'}</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-[#1E293B]">
                    {files.map((file, idx) => (
                      <tr key={idx} className={`transition-colors ${isDeploying ? 'opacity-50' : 'hover:bg-[#131B2C] cursor-pointer'}`} onClick={() => !isDeploying && toggleSelect(file.name)}>
                        <td className="px-4 py-4">
                          {selectedFiles.includes(file.name) ? <CheckSquare className="w-4 h-4 text-indigo-400" /> : <Square className="w-4 h-4 text-gray-500" />}
                        </td>
                        <td className="px-4 py-4 font-mono font-bold text-blue-300 flex items-center gap-2">
                          {file.name === 'update.sh' && <Terminal className="w-4 h-4 text-emerald-400" />} {file.name}
                        </td>
                        <td className="px-4 py-4 text-gray-400">{formatSize(file.size)}</td>
                        <td className="px-4 py-4 text-gray-500">{new Date(file.modified * 1000).toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          <div className="flex flex-col gap-3">
            <button 
              onClick={handlePreviewDeploy}
              disabled={files.length === 0 || isDeploying}
              className="w-full py-4 bg-indigo-600 hover:bg-indigo-500 disabled:bg-gray-800 disabled:text-gray-500 text-white rounded-xl font-black tracking-widest text-lg transition-all shadow-[0_0_20px_rgba(79,70,229,0.3)] disabled:shadow-none flex items-center justify-center gap-3 relative overflow-hidden"
            >
              {isDeploying ? (
                <>
                  <div className="absolute inset-0 bg-blue-500/20 animate-pulse"></div>
                  <Loader2 className="w-6 h-6 animate-spin text-blue-400 z-10" /> 
                  <span className="z-10">{lang === 'en' ? 'UPDATING EDGE DEVICE...' : '等待邊緣設備更新回報中...'}</span>
                </>
              ) : (
                <>
                  <PlayCircle className="w-6 h-6" /> 
                  {lang === 'en' ? 'REVIEW & DEPLOY TO EDGE' : '預覽部署並推播至邊緣設備'}
                </>
              )}
            </button>
            
            {isDeploying && (
              <button 
                onClick={handleEmergencyUnlock}
                className="text-sm text-gray-500 hover:text-red-400 font-medium transition-colors flex items-center justify-center gap-1 py-1"
              >
                <Unlock className="w-4 h-4" />
                {lang === 'en' ? 'Emergency Unlock (If device stops responding)' : '強制解除鎖定 (如果設備發生意外無回應)'}
              </button>
            )}
          </div>
        </div>
      </div>

      <div className="bg-[#131B2C] border border-[#1E293B] rounded-[2rem] p-6 shadow-xl mt-8">
        <div className="flex justify-between items-center mb-6 px-2">
          <h3 className="text-white font-bold text-lg flex items-center"><History className="w-5 h-5 mr-2 text-blue-400" /> {lang === 'en' ? 'Deployment History' : '歷史更新日誌'}</h3>
          <div className="flex gap-3">
             <button onClick={fetchHistoryLogs} className="text-gray-400 hover:text-white transition-colors p-2 bg-[#0B0F19] rounded-xl border border-[#1E293B]">
                <RefreshCw className="w-4 h-4" />
             </button>
             <button onClick={clearHistoryLogs} disabled={historyLogs.length === 0} className="flex items-center gap-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 px-4 py-2 rounded-xl text-sm font-bold transition-colors disabled:opacity-50">
               <Trash2 className="w-4 h-4" /> {lang === 'en' ? 'Clear Log' : '清空紀錄'}
             </button>
          </div>
        </div>
        
        <div className="bg-[#0B0F19] border border-[#1E293B] rounded-2xl overflow-hidden max-h-[300px] overflow-y-auto custom-scrollbar">
            {historyLogs.length === 0 ? (
                <div className="p-8 text-center text-gray-500 text-sm font-medium">{lang === 'en' ? 'No update history yet.' : '目前還沒有任何更新紀錄。'}</div>
            ) : (
                <table className="w-full text-left text-sm">
                    <tbody className="divide-y divide-[#1E293B]">
                        {historyLogs.map((log) => (
                            <tr key={log.id} className="hover:bg-[#131B2C] transition-colors">
                                <td className="px-6 py-4 whitespace-nowrap text-gray-500 font-mono text-xs">{log.timestamp}</td>
                                <td className="px-6 py-4 whitespace-nowrap font-bold flex items-center gap-2">
                                    {log.status === 'Deploying' && <><Loader2 className="w-4 h-4 text-blue-400 animate-spin"/> <span className="text-blue-400">{lang === 'en' ? 'Deploying' : '部署中'}</span></>}
                                    {log.status === 'Success' && <><CheckCircle2 className="w-4 h-4 text-emerald-400"/> <span className="text-emerald-400">{lang === 'en' ? 'Success' : '成功'}</span></>}
                                    {log.status === 'Failed' && <><XCircle className="w-4 h-4 text-red-400"/> <span className="text-red-400">{lang === 'en' ? 'Failed' : '失敗'}</span></>}
                                    {log.status === 'Info' && <><Terminal className="w-4 h-4 text-gray-400"/> <span className="text-gray-400">{lang === 'en' ? 'Info' : '資訊'}</span></>}
                                </td>
                                <td className="px-6 py-4 text-gray-400 w-full">{log.message}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            )}
        </div>
      </div>

      {showDeployModal && !isDeploying && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-sm px-4 animate-in fade-in zoom-in-95 duration-200">
           <div className="bg-[#131B2C] border border-blue-500/30 rounded-[2rem] shadow-2xl w-full max-w-3xl flex flex-col max-h-[85vh]">
            <div className="p-6 border-b border-[#1E293B] flex justify-between items-center bg-[#172033] rounded-t-[2rem]">
              <div>
                <h3 className="text-white text-xl font-black flex items-center tracking-wide"><AlertTriangle className="w-6 h-6 mr-3 text-orange-400" /> {lang === 'en' ? 'Deployment Review' : '部署前最終確認'}</h3>
                <p className="text-gray-400 text-sm mt-1">{lang === 'en' ? 'Please review the commands that will be executed on the Edge device.' : '請仔細檢閱即將在邊緣設備上執行的程式碼。'}</p>
              </div>
              <button onClick={() => setShowDeployModal(false)} className="text-gray-500 hover:text-white p-2 bg-[#0B0F19] rounded-xl"><X className="w-5 h-5" /></button>
            </div>
            
            <div className="p-6 flex-1 overflow-hidden flex flex-col bg-[#0B0F19]">
              <div className="flex items-center gap-2 mb-3 text-emerald-400 text-sm font-bold font-mono">
                <Terminal className="w-4 h-4"/> update.sh
              </div>
              <pre className="bg-black border border-[#2A3750] p-4 rounded-xl overflow-auto custom-scrollbar text-gray-300 font-mono text-sm flex-1 shadow-inner">
                {scriptContent}
              </pre>
            </div>

            <div className="p-6 border-t border-[#1E293B] bg-[#172033] rounded-b-[2rem] flex flex-col sm:flex-row justify-between items-center gap-4">
              <div className="text-xs text-orange-400 font-medium flex items-center">
                <AlertTriangle className="w-4 h-4 mr-2" />
                {lang === 'en' ? 'Warning: AI inference will be temporarily suspended.' : '警告：執行此操作將會短暫中斷 AI 影像防護。'}
              </div>
              <div className="flex gap-3 w-full sm:w-auto">
                <button onClick={() => setShowDeployModal(false)} className="px-6 py-3 rounded-xl text-gray-400 font-bold hover:bg-[#1E293B] transition-colors flex-1 sm:flex-none text-center">
                  {lang === 'en' ? 'Cancel' : '取消'}
                </button>
                <button onClick={executeDeployment} className="px-8 py-3 rounded-xl bg-orange-600 hover:bg-orange-500 text-white font-black transition-colors shadow-lg shadow-orange-500/25 flex-1 sm:flex-none text-center">
                  {lang === 'en' ? 'APPROVE & EXECUTE' : '我已確認，立即執行'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showSuccessModal && (
        <div className="fixed inset-0 z-[110] flex items-center justify-center bg-black/80 backdrop-blur-md px-4 animate-in fade-in zoom-in-95 duration-300">
          <div className="bg-[#131B2C] border-2 border-emerald-500/50 rounded-3xl p-8 max-w-md w-full text-center shadow-[0_0_50px_rgba(16,185,129,0.2)]">
            <div className="mx-auto w-20 h-20 bg-emerald-500/20 rounded-full flex items-center justify-center mb-6 animate-bounce">
              <ShieldCheck className="w-10 h-10 text-emerald-400" />
            </div>
            <h2 className="text-3xl font-black text-white mb-3 tracking-wide">{lang === 'en' ? 'Update Successful' : '更新成功'}</h2>
            <p className="text-gray-400 mb-8 leading-relaxed">
              {lang === 'en' ? 'The Edge device has successfully executed the update script and reloaded the system.' : '邊緣設備已成功執行更新腳本，並且已自動重啟完成模型載入。'}
              <br/><br/>
              <span className="inline-block bg-[#0B0F19] text-emerald-400 font-mono text-sm px-4 py-2 rounded-lg border border-emerald-500/30">
                🕒 {lang === 'en' ? 'Finished at' : '完成時間'}: {otaFinishTime}
              </span>
            </p>
            <button 
              onClick={handleSuccessConfirm} 
              className="w-full py-4 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl font-black tracking-widest transition-colors shadow-lg shadow-emerald-600/30"
            >
              {lang === 'en' ? 'CONFIRM & RESUME' : '確認並恢復操作'}
            </button>
          </div>
        </div>
      )}

    </div>
  );
}
