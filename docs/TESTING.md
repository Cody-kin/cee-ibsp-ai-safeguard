# 驗證與重現

執行日期：2026-11-07，Linux、Python 3.12.14、Node 24.22.1。測試僅使用合成資料、臨時 SQLite 及檔案目錄；沒有向真實 Telegram、MQTT、裝置、模型或外部 AI 發送請求。

## 結果

| 檢查 | 結果 | 能證明及不能證明的事項 |
| --- | --- | --- |
| `python3 tools/verify.py` | PASS | Python AST、JSON、Shell 語法；8 項警報邏輯及3類憑證格式；非完整密鑰審計 |
| `python -m pytest -q tests/test_regressions.py` | 27 passed，6 warnings | 真實 FastAPI in-process API、SQLite、圖片、OTA檔案、權限、邊界值與隔離協定；非外部整合 |
| `npm ci --ignore-scripts --no-audit --no-fund` | PASS | lockfile 安裝成功，未執行 dependency lifecycle scripts；未做漏洞審計 |
| `tsc --noEmit --incremental false` | PASS | 恢復嚴格型別檢查後通過 |
| `npm run lint` | FAIL | 仍有既存 explicit-any、unused-vars 及 Hooks 警告；未停用規則掩蓋 |
| `next build --no-lint` | PASS | 型別檢查、打包與14頁生成完成；不是標準 build 全部檢查通過 |
| iOS / Heltec / Jetson / Docker 端到端 | NOT RUN | 缺 macOS、板卡、相機／感測器、對應模型及服務環境 |

標準 `npm run build` 仍可能因 ESLint 錯誤失敗；不得把本次 `--no-lint` 成功當作 lint 已通過。現有警告包括 FastAPI on_event、datetime.utcnow 棄用，尚未遷移生命週期 API。

## 命令

在倉庫根目錄，以 Python 3.12 的隔離環境執行：

```bash
python3 tools/verify.py
python3 -m venv .venv
.venv/bin/python -m pip install -r tests/requirements.txt
.venv/bin/python -m pytest -q tests/test_regressions.py
```

`tests/requirements.txt` 鎖定本次使用的直接測試依賴，不是所有傳遞依賴的供應鏈鎖檔，也不是 Jetson 部署環境。測試會設定測試用環境變數並關閉背景執行緒；請在獨立 process 執行，勿與正式服務共用 Python process。

前端（本次 Node 24.22.1；Dockerfile 的 Node 20 相容性未另測）：

```bash
cd 01_cloud_server_aegis_platform/frontend
npm ci --ignore-scripts --no-audit --no-fund
./node_modules/.bin/tsc --noEmit --incremental false
npm run lint
NEXT_TELEMETRY_DISABLED=1 ./node_modules/.bin/next build --no-lint
```

最後兩個命令分別執行，以保留 lint 失敗狀態，不使用關閉型別檢查的設定。

## 27 項回歸覆蓋

匿名管理操作拒絕、一般使用者禁止控制裝置、iOS 建立帳戶欄位契約、非法角色、缺失使用者404、保留天數邊界、事件圖片上傳／讀回、非法裝置ID、OTA檔名穿越及檔案CRUD、空／零／1.0偵測設定、LoRa payload、預設拒絕unsigned OTA、Swift登入表單編碼的原始碼檢查。Swift 檢查不是編譯或模擬器測試。

原報告的0.879 mAP、100 epochs、跨樓層RF數字及成功展示屬歷史證據。此次未下載模型／資料集，未核對資料切分、標註、人物授權或評估腳本，亦未觀看影片重做驗證。
