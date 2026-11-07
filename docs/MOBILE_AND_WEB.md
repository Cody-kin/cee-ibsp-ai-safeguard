# iOS 與 Web 功能導覽

這兩個介面呈現同一個安全平台。原報告 §4.8、§4.9、§5.8 和投影片 8–10 明確涵蓋 Web 與 iOS，不能只把專案描述為 YOLO 模型。

| 工作流程 | Web | iOS | API／資料 |
| --- | --- | --- | --- |
| 身份 | `/login`、AuthGuard、登出 | LoginView、AuthViewModel | OAuth2 form login / JWT / users/me |
| 總覽 | `/` | DashboardView | analysis/current、devices、events、lorawan/latest |
| 現場影像 | Dashboard 相機卡片 | CameraStreamViewModel、SnapshotCameraView | JPEG snapshots / stream GET |
| 事件回顧 | `/events` 篩選與影像 | EventsView、事件詳情 | events、storage snapshot |
| 分析 | `/analytics` 趨勢與威脅分佈 | AnalyticsView、本地規則報告 | events、LoRa telemetry、可選 Qwen |
| 裝置 | `/devices`、`/devices/lora` | DeviceSettingsView | devices/config、閾值、assignees、下行 |
| 維護 | `/ota` | OTAManagementView（由裝置／設定流程連入） | ota/files、upload、system_command、history |
| 管理 | `/settings` | SettingsView | users CRUD、password、retention、clear |
| 通知 | bell / Zustand / toast | 本地通知、badge、event deep link | 事件輪詢；無完整 APNs |

## 已修復的跨端問題

iOS addUser 原本傳 `account`，後端只接受 `username`，已修正。兩個 Swift login helper 現在 percent-encode 保留字元，避免含 `&` 或 `+` 的帳密破壞 form。通知使用普通聲音，因現有包未提供 critical alerts entitlement。

Web 原有同名 `.ts` 與 `.tsx` notification stores 且 `.ts` 包含 JSX；已保留具實際消費者的 store 為 `.tsx`，另一個放 archive 供追溯，並統一鈴鐺資料契約。翻譯鍵、setLang、headers 型別、設定元件 props、舊導覽／登出 key 已修正。TypeScript build error 忽略設定已移除。

## 未完成的驗收

iOS 目標 18.2、Swift 5、Xcode 同步資料夾專案；Linux 無法執行 Xcode 或 iPhone Simulator。端點目前是 loopback 範例，需替換為實際測試服務；Token 需改 Keychain，原生 HTTP 錯誤處理亦有未完成處。沒有把 Swift 字串檢查稱為 native unit test。

UI 原貌仍保留。沒有重新畫假畫面，也沒有以報告截圖當成此次應用執行結果；原始截圖含身份／設備資料，未直接上傳。後續需真實瀏覽器與 iPhone 驗收登入、資料刷新、錯誤狀態、權限、通知與 OTA 書籤流程。
