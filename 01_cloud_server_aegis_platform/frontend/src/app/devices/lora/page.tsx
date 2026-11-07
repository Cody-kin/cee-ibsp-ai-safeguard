'use client';

import { useEffect, useState } from 'react';
import { ArrowLeft, Radio, ExternalLink, Activity, Gauge, Clock, Database, Server, RefreshCw, Copy } from 'lucide-react';
import { useRouter } from 'next/navigation';

export default function LoraDetailPage() {
  const router = useRouter();
  const [latest, setLatest] = useState<any>(null);
  const [devices, setDevices] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    const token = localStorage.getItem('token');
    const headers: Record<string, string> = token ? { 'Authorization': `Bearer ${token}` } : {};

    try {
      const [loraRes, devRes] = await Promise.all([
        fetch(`/api/v1/lorawan/latest?_t=${Date.now()}`, { headers }),
        fetch(`/api/v1/devices?_t=${Date.now()}`, { headers })
      ]);

      if (loraRes.ok) setLatest(await loraRes.json());
      if (devRes.ok) setDevices((await devRes.json()).data || []);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    const t = setInterval(fetchData, 3000);
    return () => clearInterval(t);
  }, []);

  const loraDevice = devices.find(d => d.id === 'LORA-001');
  const nanoDevice = devices.find(d => d.id === 'NANO-001');

  // UI display fix: swap display order to match real sensor labels.
  const mq2 = parseInt(latest?.parsed?.mq3 ?? '0') || 0;
  const mq3 = parseInt(latest?.parsed?.mq2 ?? '0') || 0;
  const receivedAt = latest?.received_at ? new Date(latest.received_at).toLocaleString() : 'No data yet';

  const chirpStackUrl = 'http://chirpstack.127.0.0.1.sslip.io:8081/';

  const openChirpStack = () => {
    window.open(chirpStackUrl, 'chirpstack_admin', 'noopener,noreferrer,width=1400,height=900');
  };

  const copyChirpStackUrl = async () => {
    try {
      await navigator.clipboard.writeText(chirpStackUrl);
      alert('ChirpStack URL 已複製，建議用新瀏覽器或無痕視窗打開。');
    } catch {
      alert(chirpStackUrl);
    }
  };

  return (
    <div className="p-8 max-w-[1400px] mx-auto space-y-8 animate-in fade-in">
      <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-5 border-b border-[#1E293B] pb-6">
        <div>
          <button
            onClick={() => router.push('/devices')}
            className="mb-5 inline-flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm font-bold"
          >
            <ArrowLeft className="w-4 h-4" /> 返回 Devices
          </button>

          <h1 className="text-3xl font-black text-white flex items-center">
            <Radio className="w-8 h-8 mr-4 text-emerald-400" />
            LoRa 緊急通訊網關
          </h1>
          <p className="text-gray-400 mt-2 text-sm font-medium">
            Node1 / Gateway / ChirpStack / Sensor telemetry overview
          </p>
          <p className="text-amber-300/80 mt-2 text-xs font-mono">
            ChirpStack 使用獨立 hostname 開啟，避免與主站登入狀態混用。Safari 建議用新視窗或無痕視窗登入。
          </p>
        </div>

        <div className="flex flex-col sm:flex-row gap-3">
          <button
            onClick={openChirpStack}
            className="bg-emerald-500/10 hover:bg-emerald-500/20 border border-emerald-500/30 text-emerald-300 px-5 py-3 rounded-xl font-bold flex items-center gap-2 transition-all"
          >
            <ExternalLink className="w-5 h-5" />
            新視窗打開 ChirpStack
          </button>
          <button
            onClick={copyChirpStackUrl}
            className="bg-[#131B2C] hover:bg-[#1E293B] border border-[#2A3750] text-gray-300 px-5 py-3 rounded-xl font-bold flex items-center gap-2 transition-all"
          >
            <Copy className="w-5 h-5" />
            複製獨立網址
          </button>
        </div>
      </div>

      {loading ? (
        <div className="text-indigo-400 font-mono animate-pulse">載入 LoRa 狀態中...</div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            <div className="bg-[#131B2C] border border-[#1E293B] rounded-2xl p-6 shadow-xl">
              <div className="flex items-center justify-between mb-5">
                <div className="text-gray-400 text-sm font-bold">Gateway</div>
                <Server className="w-5 h-5 text-emerald-400" />
              </div>
              <div className={`text-2xl font-black ${loraDevice?.status === 'online' ? 'text-emerald-400' : 'text-gray-500'}`}>
                {loraDevice?.status === 'online' ? 'ONLINE' : 'OFFLINE'}
              </div>
              <div className="text-xs text-gray-500 font-mono mt-2">ID: LORA-001</div>
            </div>

            <div className="bg-[#131B2C] border border-[#1E293B] rounded-2xl p-6 shadow-xl">
              <div className="flex items-center justify-between mb-5">
                <div className="text-gray-400 text-sm font-bold">Nano Node</div>
                <Activity className="w-5 h-5 text-indigo-400" />
              </div>
              <div className={`text-2xl font-black ${nanoDevice?.status === 'online' ? 'text-indigo-400' : 'text-gray-500'}`}>
                {nanoDevice?.status === 'online' ? 'ONLINE' : 'OFFLINE'}
              </div>
              <div className="text-xs text-gray-500 font-mono mt-2">ID: NANO-001</div>
            </div>

            <div className="bg-[#131B2C] border border-[#1E293B] rounded-2xl p-6 shadow-xl">
              <div className="flex items-center justify-between mb-5">
                <div className="text-gray-400 text-sm font-bold">Last Seen</div>
                <Clock className="w-5 h-5 text-blue-400" />
              </div>
              <div className="text-sm font-mono text-white break-all">{receivedAt}</div>
              <div className="text-xs text-gray-500 mt-2">Auto refresh every 3s</div>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div className="bg-[#131B2C] border border-[#1E293B] rounded-2xl p-6 shadow-xl">
              <h2 className="text-white text-xl font-black mb-6 flex items-center gap-3">
                <Gauge className="w-5 h-5 text-rose-400" />
                Sensor Telemetry
              </h2>

              <div className="space-y-4">
                <div className="bg-[#0B0F19] border border-[#1E293B] rounded-xl p-5">
                  <div className="flex justify-between items-center">
                    <div>
                      <div className="text-gray-400 text-sm">Smoke / Gas (MQ2)</div>
                      <div className="text-3xl font-black text-white mt-2 whitespace-nowrap tabular-nums">{mq2}</div>
                    </div>
                    <span className={`text-xs font-black px-3 py-1 rounded-full ${mq2 > 400 ? 'bg-red-500/20 text-red-400' : 'bg-emerald-500/20 text-emerald-400'}`}>
                      {mq2 > 400 ? 'WARNING' : 'NORMAL'}
                    </span>
                  </div>
                </div>

                <div className="bg-[#0B0F19] border border-[#1E293B] rounded-xl p-5">
                  <div className="flex justify-between items-center">
                    <div>
                      <div className="text-gray-400 text-sm">Alcohol (MQ3)</div>
                      <div className="text-3xl font-black text-white mt-2 whitespace-nowrap tabular-nums">{mq3}</div>
                    </div>
                    <span className={`text-xs font-black px-3 py-1 rounded-full ${mq3 > 200 ? 'bg-orange-500/20 text-orange-400' : 'bg-emerald-500/20 text-emerald-400'}`}>
                      {mq3 > 200 ? 'WARNING' : 'NORMAL'}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-[#131B2C] border border-[#1E293B] rounded-2xl p-6 shadow-xl">
              <h2 className="text-white text-xl font-black mb-6 flex items-center gap-3">
                <Database className="w-5 h-5 text-indigo-400" />
                Latest LoRaWAN Uplink
              </h2>

              <div className="space-y-3 text-sm">
                <InfoRow label="DevEUI" value={latest?.dev_eui || 'N/A'} />
                <InfoRow label="FPort" value={String(latest?.f_port ?? 'N/A')} />
                <InfoRow label="FCnt" value={String(latest?.f_cnt ?? 'N/A')} />
                <InfoRow label="DR" value={String(latest?.dr ?? 'N/A')} />
                <InfoRow label="Event Type" value={latest?.parsed?.event_type || 'N/A'} />
                <InfoRow label="Event Name" value={latest?.parsed?.event_name || 'N/A'} />
              </div>

              <div className="mt-6">
                <div className="text-gray-400 text-xs font-bold mb-2 uppercase tracking-widest">Payload</div>
                <pre className="bg-[#0B0F19] border border-[#1E293B] rounded-xl p-4 text-emerald-300 text-xs whitespace-pre-wrap break-all">
                  {latest?.payload_text || 'No payload yet'}
                </pre>
              </div>

              <button
                onClick={fetchData}
                className="mt-5 flex items-center gap-2 text-sm text-indigo-300 hover:text-white transition-colors"
              >
                <RefreshCw className="w-4 h-4" /> 手動刷新
              </button>
            </div>
          </div>
        </>
      )}
</div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4 border-b border-[#1E293B]/70 pb-2">
      <span className="text-gray-500 font-bold">{label}</span>
      <span className="text-gray-200 font-mono break-all text-right">{value}</span>
    </div>
  );
}
