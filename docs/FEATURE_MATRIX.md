# 功能與證據對照

R＝原始 Final Report（DOCX 章節／P 為 XML 段落序號）；S＝Final Presentation 投影片實際序號；I＝Interim Report PDF 頁；L＝Project Log PDF 頁。原始文件保留在私有審查區，不把學生資料或帶憑證截圖複製進倉庫。來源雜湊見 SOURCE_EVIDENCE.json。

「存在」表示找到程式，不表示已運行。「通過」只指此處明列的合成或 in-process 測試。原報告的 successful 不是本次測試結果。

| ID | 功能／原始聲稱 | 文件證據 | 程式證據 | 本次驗證 | 缺漏／限制 |
| --- | --- | --- | --- | --- | --- |
| E01 | 本地 YOLOv5 載入與推論 | R §4.1–4.2；S5–6 | [detector.py](../02_jetson_nano_ai_node/modules/detector.py) | 存在；未載入模型 | 需要 best.pt、已核對的 YOLOv5 commit、JetPack/PyTorch 相容環境 |
| E02 | 火／煙／跌倒／電話／吸煙五類警報 | R §4.2 P424–434 | [main.py](../02_jetson_nano_ai_node/main.py) | 8 個既有純邏輯案例涵蓋部分類別 | 不等於影像辨識準確率驗證；phone 在程式也標為 critical |
| E03 | 缺安全帽／缺反光衣推導 | R §4.2 P411–434 | [main.py](../02_jetson_nano_ai_node/main.py) | 邏輯存在；合成案例通過 | 實作為全畫面存在性，不是報告描述的逐 worker area 配對 |
| E04 | 雙相機輪詢、重新連線、V4L2 調整 | R §4.1 P403 | [main.py](../02_jetson_nano_ai_node/main.py) | 存在；未接 USB 相機 | 需真實相機壓測；不能以語法檢查聲稱 FPS |
| E05 | 本機 Flask JPEG/MJPEG 監視 | R §3.3、4.1 | [local_stream.py](../02_jetson_nano_ai_node/modules/local_stream.py) | 存在 | Flask、相機與端口的端到端未驗證 |
| E06 | 事件及圖片 HTTP 上傳 | R §5.2；S7 | [comms_network.py](../02_jetson_nano_ai_node/modules/comms_network.py) | 後端合成 multipart roundtrip 通過 | 修復後端 shutil 區域變數造成首次圖片上傳崩潰；未測真實 Nano 網路 |
| E07 | HTTP 與 LoRa 雙路警報 | R §3.2–3.4；S4、11 | [main.py](../02_jetson_nano_ai_node/main.py) | 兩條發送呼叫存在 | 目前兩路均嘗試發送，並非僅斷網才切換；沒有跨通道事件去重 |
| E08 | Voice SOS／DF2301Q I2C | R §4.3、5.6；S14 | [audio_detector.py](../02_jetson_nano_ai_node/modules/audio_detector.py) | CMDID、啟動抑制與雙路事件存在 | 硬件、口令與誤報率未重測 |
| E09 | MQ2/MQ3 ADC 環境遙測 | R §4.4、5.5 | [aegis_node1_lorawan_final.ino](../aegis_node1_lorawan_final/aegis_node1_lorawan_final.ino) | 韌體讀 ADC；payload 合成解析通過 | 原始值不是經校準 ppm；前端／iOS 通道對調需原接線確認 |
| E10 | 遠端偵測類別與閾值 | R §3.7、4.11 | [comms_lora.py](../02_jetson_nano_ai_node/modules/comms_lora.py) | 零閾值、1.0 邊界與空設定回歸通過 | 修復原本 0 被忽略、空配置重啟預設值的問題 |
| E11 | START / STOP | R §5.7；S15 | [comms_lora.py](../02_jetson_nano_ai_node/modules/comms_lora.py) | 串口命令存在；後端授權測試通過 | 未經 RF 下行／硬件測試；單一 pending.txt 可能被覆蓋 |
| E12 | OTA 下載／執行 | R §4.11、5.7；S15–16 | [comms_lora.py](../02_jetson_nano_ai_node/modules/comms_lora.py) | 檔案 CRUD 通過；未執行腳本 | 未有簽章、回滾與版本證明；現預設阻止 unsigned OTA |
| L01 | OTAA、AS923、OLED 時序 | R §4.5–4.6；L PDF pp46–60 | [aegis_node1_lorawan_final.ino](../aegis_node1_lorawan_final/aegis_node1_lorawan_final.ino) | 韌體與設定存在 | 未安裝 Heltec SDK／未編譯；原金鑰已清除 |
| L02 | 255MESH / ChirpStack／MQTT | R §4.6；S12 | [docker-compose.yml](../05_chirpstack_lorawan_config/docker-compose.yml) | 組態存在 | 未連接閘道、Docker 或 MQTT；basicstation 預設 eu868 與主 AS923 需部署選擇 |
| L03 | uplink 解碼、統一事件、latest 狀態 | R §4.7、5.3 | [lorawan.py](../01_cloud_server_aegis_platform/backend/app/routers/lorawan.py) | delimiter parser 合成測試通過 | 實際 webhook 未重放；HTTP uplink 身份驗證仍待補 |
| L04 | MQTT 下行與失敗保留待送命令 | R §4.11 | [lorawan.py](../01_cloud_server_aegis_platform/backend/app/routers/lorawan.py) | 存在；匿名下行被拒測試通過 | MQTT QoS0 接受不等於裝置收到；不能當作 ACK |
| L05 | 30/F → 9/F、−97 dBm、3 dB | R §5.4；S13；L PDF pp57–60 | [lorawan.py](../01_cloud_server_aegis_platform/backend/app/routers/lorawan.py) | 僅歷史報告聲稱／圖示證據 | 本次未重測，不能推論最大射程或任意建築可靠性 |
| W01 | 登入、註冊、JWT／使用者資料 | R §4.8；I Appendix D | [main.py](../01_cloud_server_aegis_platform/backend/app/main.py) | 真實 in-process 登入、JWT 與使用者 API 測試 | 未驗證 TLS、部署帳戶、密碼政策及暴力破解限流 |
| W02 | 網頁 Dashboard／節點狀態／近期風險 | R §3.6、4.8；S8 | [page.tsx](../01_cloud_server_aegis_platform/frontend/src/app/page.tsx) | 頁面存在；TypeScript 通過 | 沒有真實連線遙測的瀏覽器驗收 |
| W03 | Events 篩選、快照、事件清除／解除 | R §4.8、5.2 | [page.tsx](../01_cloud_server_aegis_platform/frontend/src/app/events/page.tsx) | 頁面存在；事件／快照 API 通過 | 原始歷史資料未載入；快照公開存取仍需設計權限 |
| W04 | Analytics 趨勢、威脅分佈 | R §4.8；S9 | [page.tsx](../01_cloud_server_aegis_platform/frontend/src/app/analytics/page.tsx) | 頁面存在；TypeScript 通過 | 後備兩點曲線只是同一讀值，不能作實測時間序列 |
| W05 | Qwen insight 與問答 | S9；I server appendix | [analysis.py](../01_cloud_server_aegis_platform/backend/app/routers/analysis.py) | 後端與前端代理存在 | 未呼叫付費外部 AI；代理權限／速率／資料外送政策待處理 |
| W06 | Devices／相機 assignees／閾值設定 | R §4.8；S9 | [page.tsx](../01_cloud_server_aegis_platform/frontend/src/app/devices/page.tsx) | 頁面存在；管理員寫入邊界測試通過 | 相機 GET／storage 尚無完整服務端逐用戶權限，UI 過濾不是安全控制 |
| W07 | LoRa 詳情、MQ2/MQ3、frame counter | R §4.8 P519；S8 | [page.tsx](../01_cloud_server_aegis_platform/frontend/src/app/devices/lora/page.tsx) | 頁面與 latest API 存在 | 通道名稱對調未擅改，需硬件驗證 |
| W08 | OTA 檔案上傳、列表、預覽、刪除 | R §3.6、4.11；S15 | [page.tsx](../01_cloud_server_aegis_platform/frontend/src/app/ota/page.tsx) | 管理員 CRUD／越界路徑回歸通過 | 前端 history JSON 端點仍未完整授權；不等於 OTA 真部署成功 |
| W09 | 設定、保留天數、改密碼、使用者管理 | R §4.8；I backend appendix | [page.tsx](../01_cloud_server_aegis_platform/frontend/src/app/settings/page.tsx) | 負保留天數／非法角色／缺失使用者測試通過 | 需後續 DB migration、審計日誌、資料庫備份 |
| W10 | 雙語介面與通知鈴鐺 | 程式補充功能 | [langStore.ts](../01_cloud_server_aegis_platform/frontend/src/store/langStore.ts) | 修復翻譯鍵與通知 store 衝突 | 位置見來源索引；部分三語支援僅存在 iOS |
| M01 | iOS 登入／session／登出 | R §4.9、5.8 | [AuthViewModel.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/AuthViewModel.swift) | Swift 程式存在；請求 contract 修復 | 未 Xcode 編譯；Token 仍在 UserDefaults，需 Keychain |
| M02 | 五頁 Tab 導航 | R §4.9；S10 | [MainTabView.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/MainTabView.swift) | Dashboard / Events / Analytics / Devices / Settings | iOS deployment target 18.2；Swift 5 設定；無 macOS build |
| M03 | Dashboard 風險／SOS／節點／感測值 | R §4.9；S10 | [DashboardViewModel.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/DashboardViewModel.swift) | 存在；5秒輪詢、事件15秒更新 | 未做裝置 UI／背景執行測試；感測通道對調未核實 |
| M04 | Events 列表／搜尋／快照／深連結 | R §4.9、5.8 | [EventsView.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/EventsView.swift) | 存在 | 未驗證多頁事件、真實相片與通知跳轉 |
| M05 | Analytics／本地判讀／Qwen 問答 | S10；L PDF pp64–66 | [AnalyticsView.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/AnalyticsView.swift) | 存在 | 本地 AI verdict 為規則文案，不等於另有本地 LLM；外部 Qwen 未測 |
| M06 | 相機 feed／快照刷新 | R §4.9、5.8 | [CameraStreamViewModel.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/CameraStreamViewModel.swift) | 存在 | 硬編碼端點須設定；實機效能與記憶體未測 |
| M07 | 裝置矩陣／角色／鏡頭權限／閾值 | S10；L PDF pp64–66 | [DeviceSettingsView.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/DeviceSettingsView.swift) | 存在 | 相機權限多為客戶端過濾；伺服器讀取面仍待加固 |
| M08 | LoRa 詳情與下行／START STOP | R §4.9、4.11 | [AISafeGuardAPIClient.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/AISafeGuardAPIClient.swift) | API 方法存在；後端命令授權回歸 | 未證明原機交付成功 |
| M09 | OTA 檔案／預覽／部署書籤／歷史 | R §4.11；S15 | [OTAManagementView.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/OTAManagementView.swift) | UI 與 API 方法存在 | 檔案請求可對接已測 backend；原生日誌與部署 UI 未執行 |
| M10 | 設定／多語／MQ baseline／帳戶管理 | 程式補充；R §4.9 | [SettingsView.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/SettingsView.swift) | 存在；新增用戶 username 欄位已修正 | 需原生端整合測試 |
| M11 | 未讀 badge／本地通知 | R §4.10；§6.6 future push | [NotificationManager.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/NotificationManager.swift) | 輪詢後本地通知存在；改普通音效 | 沒有 APNs 註冊、服務端 device token 或背景遠端 push；不得宣稱推播已完成 |
| M12 | 減少刷新與 UI 卡頓 | R §4.9 P540；L PDF pp64–66 | [DashboardViewModel.swift](../IOS%20app/AI-SafeGuard/AI-SafeGuard/DashboardViewModel.swift) | 節流與共用 view model 存在 | 沒有本次 Instruments/FPS／電量測量 |
| A01 | Telegram 早期通知／指令 | R §4.10；S14 | [tg_core.py](../01_cloud_server_aegis_platform/backend/tg_core.py) | 源碼存在；token 環境化 | Compose 未啟動此 bot，未發送訊息；需核對其獨立部署 |
| A02 | 模型 0.879 mAP@0.5 / 100 epochs | R §4.2 P436–438；S5–6 | [detector.py](../02_jetson_nano_ai_node/modules/detector.py) | 僅原報告數據 | 沒有重跑訓練或驗證；I p5–7 的約0.875 是不同階段，不能混成一次測試 |
| A03 | 原 LoRa Node2 bridge / PWM fan | I pp15–22 | [comms_manager.py](../02_jetson_nano_ai_node/modules/comms_manager.py) | 歷史文件含舊設計；現 zip 不含完整 Node2/fan standalone | 視為舊階段／缺失檔案，不自行補寫假原作 |
| A04 | 離線圖片緩存／多節點／簽章 OTA | R §6.6 | [main.py](../02_jetson_nano_ai_node/main.py) | 報告列未來工作；目前缺失 | 不列入已完成功能 |
