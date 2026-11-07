import { create } from 'zustand';
import { persist } from 'zustand/middleware';

const dict = {
  en: {
    noImage: 'No image',
    // Menu & Common
    menuOverview: 'OVERVIEW', menuDashboard: 'Dashboard', menuDevices: 'Devices & LoRa', menuEvents: 'Events & Alerts',
    menuAnalytics: 'ANALYTICS', menuSensor: 'Sensor Analytics', menuConfig: 'CONFIGURATION', menuSettings: 'Settings',
    btnLogout: 'Logout', btnSwitchLang: '切換至繁體中文', appName: 'AI-SafeGuard',
    online: 'ONLINE', offline: 'OFFLINE', critical: 'CRITICAL', high: 'HIGH', info: 'INFO', action: 'Action', search: 'Search...',
    // Devices Page
    devTitle: 'Edge Device Matrix', devDesc: 'Real-time health monitoring for Vision Nodes and LoRa Gateways.',
    devVision: 'AI Vision Node', devSensor: 'LoRa Sensor Gateway', devLastSeen: 'Last Seen', devEvents: 'Events Caught',
    devWait: 'Waiting for edge device signals...',
    // Events Page
    evtTitle: 'Global Event Repository', evtDesc: 'Smart filtering for abnormal threats and alerts.',
    evtAll: 'All Levels', colTime: 'Timestamp', colNode: 'Source Node', colEvent: 'Event Name', colSeverity: 'Severity', colDesc: 'Description', colSnap: 'Snapshot', evtEmpty: 'No matching events found.',
    // Notifications
    notifTitle: 'Notifications', notifEmpty: 'No new notifications.', markRead: 'Mark all as read',
    // Analytics & Dashboard & Settings (保留之前的)
    dashVisionNode: 'Vision Node', dashGateway: 'LoRa Gateway', dashTotalEvents: 'Total Events Today', dashHealth: 'System Health',
    dashStream: 'Jetson Nano Vision Stream', dashAiInsight: 'AI Live Insight', btnTimeline: 'View Timeline',
    aiReading: 'AI is analyzing live data...', aiActive: 'System active. Intercepted {count} events in the last 15 mins.', aiEmpty: 'System is stable. No recent events detected.',
    anaTitle: 'Data Analytics & Threats', anaDesc: 'Time-series threat distribution combined with Qwen LLM insights.',
    tabToday: 'Today', tabWeek: '1 Week', tabMonth: '1 Month', chartTitle: 'Threat Interception Trend', visionLabel: 'AI Vision', sensorLabel: 'LoRa Sensor',
    aiReportTitle: 'Qwen AI Insight Report', btnGenerate: 'Generate Insight', chatTitle: 'Ask AI Copilot', chatPlaceholder: 'Ask a question...',
    setProfileTitle: 'Profile Settings', setProfileDesc: 'Manage your personal account details.', setDbTitle: 'Database Cleanup Rules', setDbDesc: 'System will auto-delete records older than specified days.',
    setUserTitle: 'User & Role Management', setDangerTitle: 'Danger Zone', btnSave: 'Save', btnAdd: 'Add', btnClear: 'Clear All Data',
    pwdChange: 'Change Password', pwdPlaceholder: 'New Password', btnUpdate: 'Update',
  },
  zh: {
    noImage: '無影像',
    // Menu & Common
    menuOverview: '系統總覽', menuDashboard: '戰情儀表板', menuDevices: '邊緣設備管理', menuEvents: '歷史告警與事件',
    menuAnalytics: '數據洞察', menuSensor: '感測器與 AI 分析', menuConfig: '系統配置', menuSettings: '系統設置',
    btnLogout: '登出系統', btnSwitchLang: 'Switch to English', appName: 'AI-SafeGuard (安防矩陣)',
    online: '連線中', offline: '已離線', critical: '高危險', high: '警告', info: '一般', action: '操作', search: '搜尋設備 ID 或事件...',
    // Devices Page
    devTitle: '邊緣設備矩陣', devDesc: '即時監控所有 Jetson Nano 與 LoRa 閘道器的連線健康度。',
    devVision: '視覺邊緣節點', devSensor: 'LoRa 感測閘道器', devLastSeen: '最後通訊', devEvents: '攔截事件數',
    devWait: '等待邊緣設備接入訊號中...',
    // Events Page
    evtTitle: '全局事件庫', evtDesc: '智慧型多重篩選，精準定位異常威脅。',
    evtAll: '所有等級', colTime: '時間戳記', colNode: '來源節點', colEvent: '事件名稱', colSeverity: '嚴重程度', colDesc: '詳細描述', colSnap: '現場截圖', evtEmpty: '無符合條件的事件紀錄',
    // Notifications
    notifTitle: '系統通知', notifEmpty: '目前沒有新通知', markRead: '全部標示為已讀',
    // Analytics & Dashboard & Settings (保留)
    dashVisionNode: '視覺邊緣節點', dashGateway: 'LoRa 閘道器', dashTotalEvents: '今日攔截總數', dashHealth: '系統健康度',
    dashStream: 'Jetson Nano 現場實時影像', dashAiInsight: 'AI 現場綜合研判', btnTimeline: '查看歷史時間線',
    aiReading: 'AI 正在讀取並分析現場數據...', aiActive: '系統運行中。過去 15 分鐘共攔截 {count} 筆動態。', aiEmpty: '現場狀況平靜，暫無異常事件。',
    anaTitle: '數據與威脅分析', anaDesc: '基於 AI-SafeGuard 攔截事件的時間序列分佈與大模型深度洞察。',
    tabToday: '當日', tabWeek: '1 週', tabMonth: '1 個月', chartTitle: '多維度威脅攔截趨勢', visionLabel: '視覺 AI', sensorLabel: 'LoRa 感測',
    aiReportTitle: '通義千問 (Qwen) 數據洞察', btnGenerate: '生成最新報告', chatTitle: 'AI 助理 (Copilot)', chatPlaceholder: '請輸入問題...',
    setProfileTitle: '個人帳號設定', setProfileDesc: '管理您的帳號資訊與個人偏好。', setDbTitle: '資料庫清理規則', setDbDesc: '系統將自動刪除超過指定天數的歷史紀錄與照片。',
    setUserTitle: '用戶與權限管理', setDangerTitle: '危險操作區域', btnSave: '儲存', btnAdd: '新增', btnClear: '一鍵清空資料',
    pwdChange: '修改密碼', pwdPlaceholder: '輸入新密碼', btnUpdate: '更新密碼',
  }
};

type Lang = 'en' | 'zh';
interface LangState { lang: Lang; setLang: (lang: Lang) => void; toggleLang: () => void; t: (key: keyof typeof dict['en'], params?: Record<string, string | number>) => string; }
export const useLangStore = create<LangState>()(
  persist((set, get) => ({
    lang: 'en', setLang: (lang) => set({ lang }), toggleLang: () => set((state) => ({ lang: state.lang === 'en' ? 'zh' : 'en' })),
    t: (key, params) => { let text = dict[get().lang][key] || key; if (params) { Object.keys(params).forEach(k => { text = text.replace(`{${k}}`, String(params[k])); }); } return text; },
  }), { name: 'aegis-lang-setting' })
);
