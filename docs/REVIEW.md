# 整理與驗證報告

本次補充審查取代初次僅盤點報告的結論。已抽取並閱讀最終報告 DOCX、139頁中期報告、71頁日誌、19頁最終簡報及其餘模板／評核文件的文字，並對照全部發布來源模組；未逐張對所有截圖作視覺鑑證。來源雜湊見 SOURCE_EVIDENCE.json，43項功能證據見 FEATURE_MATRIX.md。原始資料保留在私人工作區；OneDrive 未修改。

## 修復與整理

- 初次清理的憑證、LoRaWAN金鑰、伺服器位址、個人Xcode狀態、照片／訓練輸出及歷史Git資料繼續排除；機密設定改為環境變數／空值。
- 修復第一次事件圖片上傳的 `shutil` 區域變數崩潰；裝置／事件／OTA檔名檢查，影像串流frame限制10MB，保留天數限制1–3650。
- 裝置設定、系統命令、OTA管理、LoRa下行及debug加入後端管理員檢查；使用者角色限制admin/user，刪除不存在帳戶回404。
- 修正零閾值、1.0閾值及明確空配置的處理；Nano網路模組讀取設定環境。沒有改變未確認的MQ2/MQ3實際接線語意。
- 未簽章OTA預設禁止執行；`ALLOW_UNSIGNED_OTA=1`僅為明確開啟的實驗室相容選項，不構成簽章驗證或可靠更新機制。
- iOS新增帳戶改用後端username欄位；兩個登入helper正確編碼保留字元；移除未有entitlement支持的critical通知聲音。
- 前端取消隱藏TypeScript/ESLint錯誤，合併不一致通知store，修正登出token鍵／導航、翻譯鍵、headers型別及元件介面。替代store保存在archive文字檔。
- 新增27項回歸、完整模組／API索引、架構、iOS／網頁說明、功能證據矩陣及版權準備。測試詳見TESTING；lint仍失敗，未宣稱完全建置就緒。

## 未解決的部署與證據限制

1. 事件上傳、部分裝置讀取／串流、靜態圖片與AI代理仍未完成身份驗證／授權／限流；camera assignees只是UI過濾，並非完整RBAC。此次管理操作保護不能代表全系統安全。
2. 無跨HTTP/LoRa事件去重；MQTT QoS0不代表裝置ACK，單一pending命令可能覆蓋。需要佇列、重送、TTL與冪等性設計。
3. OTA缺少簽章、回滾、版本證明及完整設備認證。歷史patch/fix/update腳本不是已核准的部署或migration流程。
4. PPE目前為整張畫面的存在性推論，沒有逐人配對；多人物場景可能漏報。感測值是ADC原始值，非校準ppm；MQ通道交換需要接線核對。
5. 資料庫沒有報告所述獨立MQ、source/path欄位；部分遙測只留在描述或latest JSON。/tmp檔案不是可靠長期保存。APNs、離線緩存、簽章OTA等未完成。
6. 未驗證Docker服務整合、真實PostgreSQL/Redis/MQTT、Heltec編譯、Jetson推論及iOS原生建置。Linux測試無法證明硬件效能或App Store可發布。
7. 模型與約2GB資料集只盤點檔案，未下載評估；無法確認來源、授權、資料洩漏或報告準確率。附錄列出的CLEAN.zip／部分資料夾與實際提供的Final.zip不一致，詳見ARCHITECTURE。
8. 憑證已從發布副本移除，但共享原件中憑證未由本次撤銷，部署前需在相關服務輪替。未做完整滲透測試或漏洞資料庫審計。

## 依賴與權屬

雲端requirements尚未完整鎖定；測試版本獨立記於tests/requirements.txt。前端有npm鎖檔。Jetson需對應JetPack/CUDA、torch、OpenCV、serial／音訊與YOLOv5版本；Heltec需板卡SDK與區域設定；iOS需macOS/Xcode、iOS18.2部署目標及簽章設定。

保留ChirpStack局部MIT及DFRobot原作者聲明，不擴大到整個專案。YOLOv5、權重／資料集、字型及圖示需分別核實。學生報告、學號、評核／簽名、人物樣本與原始憑證未發布；作者後續已授權公開原創內容；第三方及提交隱私處理見PUBLICATION_REVIEW。版權登記只研究和備料，未提交或付款，也未決定共同作者／權利人。
