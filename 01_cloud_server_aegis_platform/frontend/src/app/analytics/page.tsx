'use client';

import { useState, useEffect, useRef } from 'react';
import {
  Activity,
  BrainCircuit,
  ShieldAlert,
  LineChart as ChartIcon,
  Wind,
  Send,
  Bot,
  User,
  FileText,
  Loader2,
  Trash2
} from 'lucide-react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
  Legend,
  ReferenceLine,
  Cell,
  LabelList
} from 'recharts';
import { useLangStore } from '@/store/langStore';

const COLORS = ['#ef4444', '#f97316', '#eab308', '#8b5cf6', '#06b6d4', '#10b981', '#ec4899'];

export default function AnalyticsPage() {
  const { lang } = useLangStore();

  const [events, setEvents] = useState<any[]>([]);
  const [loraLatest, setLoraLatest] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [mq2Baseline, setMq2Baseline] = useState(0);
  const [isClient, setIsClient] = useState(false);

  const getDefaultMsg = () => [{
    role: 'ai',
    text: lang === 'en'
      ? 'Hello, I am your AI-SafeGuard Tactical Assistant. LoRa telemetry and edge-node events are synchronized.'
      : '你好，我是 AI-SafeGuard 戰術助手。LoRa 遙測與邊緣節點事件已同步。'
  }];

  const [chatInput, setChatInput] = useState('');
  const [chatHistory, setChatHistory] = useState<any[]>([]);
  const [isAiTyping, setIsAiTyping] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const chatEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setIsClient(true);
    setMq2Baseline(parseInt(localStorage.getItem('aegis_mq2_baseline') || '0'));

    const saved = localStorage.getItem('aegis_ai_chat');
    if (saved) {
      try {
        setChatHistory(JSON.parse(saved));
      } catch {
        setChatHistory(getDefaultMsg());
      }
    } else {
      setChatHistory(getDefaultMsg());
    }
  }, [lang]);

  useEffect(() => {
    if (isClient && chatHistory.length > 0) {
      localStorage.setItem('aegis_ai_chat', JSON.stringify(chatHistory));
    }
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chatHistory, isClient]);

  const fetchData = async () => {
    const token = localStorage.getItem('token');
    const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {};

    try {
      const [eventsRes, loraRes] = await Promise.all([
        fetch(`/api/v1/events?_t=${Date.now()}`, { headers }),
        fetch(`/api/v1/lorawan/latest?_t=${Date.now()}`, { headers })
      ]);

      if (eventsRes.ok) {
        const data = await eventsRes.json();
        setEvents(data.data || []);
      }

      if (loraRes.ok) {
        const data = await loraRes.json();
        if (data?.status === 'success') setLoraLatest(data);
      }
    } catch (err) {
      console.error('Analytics fetch failed:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 3000);
    return () => clearInterval(interval);
  }, []);

  const parseTime = (ts: string) => {
    if (!ts) return Date.now();
    return new Date(ts.endsWith('Z') ? ts : ts + 'Z').getTime();
  };

  // Display mapping fix:
  // Physical sensor labels are currently reversed in parsed payload.
  const loraMq2Raw = parseInt(loraLatest?.parsed?.mq3 ?? '0') || 0;
  const loraMq3Raw = parseInt(loraLatest?.parsed?.mq2 ?? '0') || 0;
  const loraMq2 = Math.max(0, loraMq2Raw - mq2Baseline);
  const loraMq3 = loraMq3Raw;

  const loraTime = loraLatest?.received_at ? new Date(loraLatest.received_at) : new Date();

  const eventSensorData = events
    .filter(e => {
      const text = String(e.description || '');
      return text.includes('[Gas:') && String(e.event_name || '').toLowerCase() !== 'heartbeat';
    })
    .slice(0, 20)
    .reverse()
    .map(e => {
      const match = String(e.description || '').match(/\[Gas:([^\/\]]+)\/([^\]]+)\]/i);
      const gasA = match ? parseInt(match[1]) || 0 : 0;
      const gasB = match ? parseInt(match[2]) || 0 : 0;

      // Display mapping fix for legacy [Gas:a/b] descriptions.
      const mq2 = gasA;
      const mq3 = gasB;

      return {
        time: new Date(e.timestamp.endsWith('Z') ? e.timestamp : e.timestamp + 'Z').toLocaleTimeString(),
        mq2: Math.max(0, mq2 - mq2Baseline),
        mq3
      };
    });

  const loraTelemetryData = loraLatest?.status === 'success'
    ? [
        {
          time: new Date(loraTime.getTime() - 30000).toLocaleTimeString(),
          mq2: loraMq2,
          mq3: loraMq3
        },
        {
          time: loraTime.toLocaleTimeString(),
          mq2: loraMq2,
          mq3: loraMq3
        }
      ]
    : [];

  const sensorData = eventSensorData.length > 0 ? eventSensorData : loraTelemetryData;

  const threatEvents = events.filter(e => {
    const name = String(e.event_name || '').toLowerCase();
    const desc = String(e.description || '').toLowerCase();
    return name !== 'heartbeat'
      && !desc.includes('node1_alive')
      && ['critical', 'high', 'warning'].includes(String(e.severity || '').toLowerCase());
  });

  const visionMap: Record<string, number> = {};
  events
    .filter(e => e.event_type === 'ai_vision')
    .forEach(e => {
      const name = e.event_name || 'AI Vision';
      visionMap[name] = (visionMap[name] || 0) + 1;
    });

  const visionData = Object.entries(visionMap).map(([name, count], idx) => ({
    name,
    count,
    color: COLORS[idx % COLORS.length]
  }));

  const handleGenerateReport = async () => {
    setIsGenerating(true);
    setIsAiTyping(true);

    try {
      const token = localStorage.getItem('token');
      const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {};
      const res = await fetch(`/api/v1/analysis/qwen-insight?_t=${Date.now()}`, { headers });

      let report = '';
      if (res.ok) {
        const data = await res.json();
        report = data.report || data.message || '';
      }

      if (!report) {
        report = lang === 'en'
          ? `Status: ${threatEvents.length} active high-risk events. MQ2=${loraMq2}, MQ3=${loraMq3}. LoRa uplink is ${loraLatest?.status === 'success' ? 'active' : 'waiting'}.`
          : `狀態：目前有 ${threatEvents.length} 個高風險事件。MQ2=${loraMq2}，MQ3=${loraMq3}。LoRa 上行狀態：${loraLatest?.status === 'success' ? '正常' : '等待資料'}。`;
      }

      setChatHistory(prev => [...prev, { role: 'ai', text: report }]);
    } catch {
      setChatHistory(prev => [
        ...prev,
        {
          role: 'ai',
          text: lang === 'en'
            ? 'Unable to contact the AI report service, but telemetry is still being displayed locally.'
            : '暫時無法連接 AI 報告服務，但本地遙測資料仍可正常顯示。'
        }
      ]);
    } finally {
      setIsGenerating(false);
      setIsAiTyping(false);
    }
  };

  const handleSendChat = async (e: React.FormEvent) => {
    e.preventDefault();

    const msg = chatInput.trim();
    if (!msg) return;

    setChatInput('');
    setChatHistory(prev => [...prev, { role: 'user', text: msg }]);
    setIsAiTyping(true);

    try {
      const token = localStorage.getItem('token');
      const headers: any = { 'Content-Type': 'application/json' };
      if (token) headers.Authorization = `Bearer ${token}`;

      const res = await fetch('/api/v1/analysis/chat', {
        method: 'POST',
        headers,
        body: JSON.stringify({ message: msg })
      });

      let answer = '';
      if (res.ok) {
        const data = await res.json();
        answer = data.answer || data.response || data.message || data.report || '';
      }

      if (!answer) {
        answer = lang === 'en'
          ? `Current telemetry: MQ2=${loraMq2}, MQ3=${loraMq3}. Recent high-risk events: ${threatEvents.length}.`
          : `目前遙測：MQ2=${loraMq2}，MQ3=${loraMq3}。近期高風險事件數：${threatEvents.length}。`;
      }

      setChatHistory(prev => [...prev, { role: 'ai', text: answer }]);
    } catch {
      setChatHistory(prev => [
        ...prev,
        {
          role: 'ai',
          text: lang === 'en'
            ? `I can still read local telemetry: MQ2=${loraMq2}, MQ3=${loraMq3}.`
            : `我仍可讀取本地遙測：MQ2=${loraMq2}，MQ3=${loraMq3}。`
        }
      ]);
    } finally {
      setIsAiTyping(false);
    }
  };

  const handleClearChat = () => {
    const msg = getDefaultMsg();
    setChatHistory(msg);
    localStorage.setItem('aegis_ai_chat', JSON.stringify(msg));
  };

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-indigo-400 font-mono gap-4">
        <Loader2 className="w-8 h-8 animate-spin" />
        <span className="tracking-widest text-sm uppercase">
          {lang === 'en' ? 'Initializing Analytics Engine...' : '正在初始化分析引擎...'}
        </span>
      </div>
    );
  }

  if (!isClient) return null;

  return (
    <div className="p-8 max-w-[1600px] mx-auto space-y-8 pb-10 animate-in fade-in duration-500">
      <div className="flex items-center justify-between border-b border-[#1E293B] pb-6">
        <div>
          <h1 className="text-3xl font-black text-white flex items-center tracking-tight">
            <ChartIcon className="w-8 h-8 mr-4 text-indigo-400" />
            {lang === 'en' ? 'Data Analytics & Threats' : '數據分析與威脅情報'}
          </h1>
          <p className="text-gray-400 mt-2 text-sm font-medium">
            {lang === 'en' ? 'Real-time LoRa telemetry, threat intelligence, and AI Copilot.' : '即時 LoRa 遙測、威脅情報與 AI 助手。'}
          </p>
        </div>

        <div className="bg-indigo-500/10 border border-indigo-500/20 px-4 py-2 rounded-xl text-indigo-400 font-mono text-xs font-bold tracking-widest flex items-center shadow-lg">
          <Activity className="w-4 h-4 mr-2 animate-pulse" />
          {lang === 'en' ? 'LIVE SYNC' : '即時同步'}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] p-6 shadow-2xl flex flex-col h-[480px]">
          <div className="flex items-start justify-between mb-6 gap-4">
            <h2 className="text-xl font-bold text-white flex items-center">
              <Wind className="w-5 h-5 mr-3 text-emerald-400" />
              {lang === 'en' ? 'Sensor Telemetry' : '感測器遙測'} (MQ2 / MQ3)
            </h2>

            <div className="text-right text-xs font-mono text-gray-400 whitespace-nowrap min-w-[90px]">
              <div className="whitespace-nowrap">MQ2: <span className="inline-block min-w-[4ch] text-right text-rose-300 font-bold tabular-nums whitespace-nowrap">{loraMq2}</span></div>
              <div className="whitespace-nowrap">MQ3: <span className="inline-block min-w-[4ch] text-right text-emerald-300 font-bold tabular-nums whitespace-nowrap">{loraMq3}</span></div>
            </div>
          </div>

          {sensorData.length === 0 ? (
            <div className="flex-1 flex flex-col items-center justify-center text-gray-500 font-mono bg-[#0B0F19] rounded-2xl border border-[#1E293B] shadow-inner">
              <Activity className="w-8 h-8 mb-3 opacity-20" />
              {lang === 'en' ? 'Waiting for telemetry data...' : '等待遙測數據中...'}
            </div>
          ) : (
            <div className="flex-1 w-full relative bg-[#0B0F19] rounded-2xl border border-[#1E293B] p-4 shadow-inner">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={sensorData} margin={{ top: 20, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorMq2" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f43f5e" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#f43f5e" stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="colorMq3" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                    </linearGradient>
                  </defs>

                  <CartesianGrid strokeDasharray="3 3" stroke="#1E293B" vertical={false} />
                  <XAxis dataKey="time" stroke="#475569" fontSize={10} tickMargin={10} />
                  <YAxis stroke="#475569" fontSize={10} />
                  <RechartsTooltip
                    contentStyle={{
                      backgroundColor: '#0B0F19',
                      borderColor: '#1E293B',
                      borderRadius: '12px',
                      color: '#f8fafc',
                      boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.5)'
                    }}
                    itemStyle={{ fontSize: '12px', fontWeight: 'bold' }}
                  />
                  <Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: '12px', color: '#94a3b8' }} />
                  <ReferenceLine y={400} stroke="#ef4444" strokeDasharray="5 5" label={{ position: 'insideTopLeft', value: lang === 'en' ? 'MQ2 Danger (>400)' : 'MQ2 危險 (>400)', fill: '#ef4444', fontSize: 10 }} />
                  <ReferenceLine y={200} stroke="#f59e0b" strokeDasharray="5 5" label={{ position: 'insideTopLeft', value: lang === 'en' ? 'MQ3 Danger (>200)' : 'MQ3 危險 (>200)', fill: '#f59e0b', fontSize: 10 }} />
                  <Area type="monotone" dataKey="mq2" name={lang === 'en' ? 'Smoke/Gas' : '煙霧/氣體'} stroke="#f43f5e" strokeWidth={3} fillOpacity={1} fill="url(#colorMq2)" />
                  <Area type="monotone" dataKey="mq3" name={lang === 'en' ? 'Alcohol' : '酒精'} stroke="#10b981" strokeWidth={3} fillOpacity={1} fill="url(#colorMq3)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>

        <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] p-6 shadow-2xl flex flex-col h-[480px]">
          <h2 className="text-xl font-bold text-white mb-6 flex items-center">
            <BrainCircuit className="w-5 h-5 mr-3 text-rose-400" />
            {lang === 'en' ? 'AI Vision Threat Distribution' : 'AI 視覺威脅分佈'}
          </h2>

          {visionData.length === 0 ? (
            <div className="flex-1 flex flex-col items-center justify-center text-gray-500 font-mono bg-[#0B0F19] rounded-2xl border border-[#1E293B] shadow-inner">
              <ShieldAlert className="w-8 h-8 mb-3 opacity-20" />
              {lang === 'en' ? 'Zero threats detected' : '未偵測到任何威脅'}
            </div>
          ) : (
            <div className="flex-1 w-full relative bg-[#0B0F19] rounded-2xl border border-[#1E293B] p-4 shadow-inner">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={visionData} margin={{ top: 10, right: 20, left: 10, bottom: 0 }} layout="vertical">
                  <CartesianGrid strokeDasharray="3 3" stroke="#1E293B" horizontal={false} />
                  <XAxis type="number" stroke="#475569" fontSize={10} />
                  <YAxis dataKey="name" type="category" stroke="#cbd5e1" fontSize={11} width={130} />
                  <RechartsTooltip
                    cursor={{ fill: '#172033' }}
                    contentStyle={{
                      backgroundColor: '#0B0F19',
                      borderColor: '#1E293B',
                      borderRadius: '12px',
                      color: '#f8fafc',
                      boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.5)'
                    }}
                  />
                  <Bar dataKey="count" name={lang === 'en' ? 'Detection Count' : '偵測次數'} radius={[0, 6, 6, 0]} barSize={32}>
                    <LabelList dataKey="count" position="right" fill="#f1f5f9" fontSize={12} fontWeight="bold" offset={10} />
                    {visionData.map((entry, index) => <Cell key={`cell-${index}`} fill={entry.color} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>
      </div>

      <div className="bg-[#131B2C] border border-[#1E293B] rounded-[1.5rem] shadow-2xl overflow-hidden flex flex-col h-[450px]">
        <div className="bg-[#0B0F19]/50 backdrop-blur-md border-b border-[#1E293B] p-5 flex items-center justify-between">
          <div className="flex items-center">
            <Bot className="w-6 h-6 text-indigo-400 mr-3" />
            <h2 className="text-lg font-bold text-white tracking-wide">
              {lang === 'en' ? 'AI Copilot Assistant' : 'AI 戰術助手'}
            </h2>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={handleClearChat}
              className="p-2 text-slate-400 hover:text-rose-400 hover:bg-rose-400/10 rounded-lg transition-colors outline-none border-none focus:ring-0"
              title={lang === 'en' ? 'Clear Chat' : '清除聊天紀錄'}
            >
              <Trash2 className="w-4 h-4" />
            </button>

            <button
              onClick={handleGenerateReport}
              disabled={isGenerating || isAiTyping}
              className={`text-sm px-6 py-2.5 rounded-xl flex items-center font-bold transition-all ${(isGenerating || isAiTyping) ? 'bg-indigo-600/20 text-indigo-400/50 cursor-not-allowed' : 'bg-indigo-600 hover:bg-indigo-500 text-white shadow-lg shadow-indigo-500/20 outline-none border-none focus:ring-0'}`}
            >
              {(isGenerating || isAiTyping)
                ? <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> {lang === 'en' ? 'Analyzing...' : '分析中...'}</>
                : <><FileText className="w-4 h-4 mr-2" /> {lang === 'en' ? 'One-Click Report' : '一鍵生成報告'}</>
              }
            </button>
          </div>
        </div>

        <div className="flex-1 p-6 overflow-y-auto space-y-5 bg-[#0B0F19]/30 custom-scrollbar">
          {chatHistory.map((msg, idx) => (
            <div key={idx} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
              <div className={`max-w-[75%] rounded-[1.25rem] px-5 py-4 text-sm leading-relaxed flex items-start shadow-md ${msg.role === 'user' ? 'bg-indigo-600 text-white rounded-tr-none' : 'bg-[#172033] text-gray-200 border border-[#2A3750] rounded-tl-none'}`}>
                {msg.role === 'ai' && <BrainCircuit className="w-5 h-5 mr-3 mt-0.5 text-indigo-400 flex-shrink-0" />}
                {msg.role === 'user' && <User className="w-5 h-5 mr-3 mt-0.5 text-indigo-300 flex-shrink-0" />}
                <span className="whitespace-pre-wrap">{msg.text}</span>
              </div>
            </div>
          ))}

          {isAiTyping && (
            <div className="flex justify-start">
              <div className="max-w-[75%] rounded-[1.25rem] rounded-tl-none px-5 py-4 text-sm bg-[#172033] text-gray-400 border border-[#2A3750] flex items-center italic shadow-md">
                <Loader2 className="w-4 h-4 mr-3 animate-spin text-indigo-500" />
                {lang === 'en' ? 'AI is thinking...' : 'AI 正在思考...'}
              </div>
            </div>
          )}

          <div ref={chatEndRef} />
        </div>

        <form onSubmit={handleSendChat} className="p-4 bg-[#0B0F19]/50 backdrop-blur-md border-t border-[#1E293B] flex items-center gap-3">
          <input
            type="text"
            value={chatInput}
            onChange={(e) => setChatInput(e.target.value)}
            placeholder={lang === 'en' ? 'Type a command...' : '輸入指令...'}
            className="flex-1 bg-[#0B0F19] border border-[#2A3750] rounded-xl px-4 py-3 text-white text-sm outline-none focus:border-indigo-500"
          />
          <button
            type="submit"
            className="bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl px-5 py-3 font-bold flex items-center gap-2"
          >
            <Send className="w-4 h-4" />
            {lang === 'en' ? 'Send' : '送出'}
          </button>
        </form>
      </div>
    </div>
  );
}
