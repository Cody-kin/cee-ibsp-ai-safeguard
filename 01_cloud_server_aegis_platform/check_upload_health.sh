#!/bin/bash
echo "========================================================"
echo " 🩺 AI-SafeGuard OTA 上傳功能全面體檢報告"
echo "========================================================"

# 1. 檢查伺服器硬碟空間 (是不是塞爆了導致無法寫入)
echo -e "\n[1/5] 💾 檢查伺服器磁碟剩餘空間..."
df -h / | awk 'NR==2 {print "  -> 根目錄可用空間: " $4 " (已使用 " $5 ")"}'

# 2. 檢查 Nginx 的 1MB 上傳限制 (如果有裝的話)
echo -e "\n[2/5] 🌐 檢查 Nginx 代理伺服器上傳限制..."
if command -v nginx > /dev/null; then
    LIMIT=$(grep -r -i "client_max_body_size" /etc/nginx/ 2>/dev/null | head -n 1)
    if [ -z "$LIMIT" ]; then
        echo -e "  -> ⚠️ 警告：未設定 client_max_body_size，Nginx 預設會阻擋超過 1MB 的檔案！"
    else
        echo -e "  -> ✅ Nginx 已設定：$LIMIT"
    fi
else
    echo "  -> ℹ️ 未偵測到 Nginx 服務，跳過此檢查。"
fi

# 3. 檢查 Docker 容器內的 Python 套件 (少了就無法解析上傳)
echo -e "\n[3/5] 🐍 檢查 FastAPI 上傳必備套件 (python-multipart)..."
if docker compose exec backend pip show python-multipart > /dev/null 2>&1; then
    echo "  -> ✅ python-multipart 已安裝！"
else
    echo "  -> ❌ 致命錯誤：backend 容器內缺少 python-multipart 套件！"
fi

# 4. 檢查 Docker 容器內的資料夾讀寫權限
echo -e "\n[4/5] 📂 檢查 /tmp/aegis_ota 資料夾讀寫權限..."
docker compose exec backend sh -c '
if [ ! -d "/tmp/aegis_ota" ]; then
    echo "  -> ❌ 資料夾不存在！嘗試建立..."
    mkdir -p /tmp/aegis_ota
fi
if [ -w "/tmp/aegis_ota" ]; then
    echo "  -> ✅ /tmp/aegis_ota 具有可寫入權限！"
else
    echo "  -> ❌ 致命錯誤：/tmp/aegis_ota 權限不足 (Permission Denied)！"
    chmod 777 /tmp/aegis_ota
    echo "  -> 🔧 已嘗試強制修復為 777 權限。"
fi
'

# 5. 檢查 Backend 近期的報錯日誌
echo -e "\n[5/5] 📜 檢查近期 Backend API 錯誤日誌 (攔截 413, 422, 500)..."
ERROR_LOGS=$(docker compose logs --tail=100 backend | grep -iE "entity too large|error|traceback|422 unprocessable")
if [ -z "$ERROR_LOGS" ]; then
    echo "  -> ✅ 近期無明顯上傳錯誤日誌。"
else
    echo "  -> ⚠️ 發現疑似報錯紀錄："
    echo "$ERROR_LOGS" | tail -n 5
fi

echo "========================================================"
echo " 體檢結束！請根據上方紅色的 ❌ 進行修復。"
echo "========================================================"
