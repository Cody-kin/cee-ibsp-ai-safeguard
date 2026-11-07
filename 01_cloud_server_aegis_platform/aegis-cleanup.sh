#!/bin/bash
# AI-SafeGuard 自動清理腳本
# 功能：自動刪除超過 7 天的舊快照，防止伺服器硬碟爆滿

STORAGE_DIR="/root/aegis-cloud-platform/frontend/public/storage"
LOG_FILE="/var/log/aegis-cleanup.log"

echo "=====================================" >> $LOG_FILE
echo "🕒 執行時間: $(date)" >> $LOG_FILE

if [ -d "$STORAGE_DIR" ]; then
    # 尋找並刪除 7 天前的 .jpg 檔案
    DELETED_FILES=$(find "$STORAGE_DIR" -type f -name "*.jpg" -mtime +7 -print -delete)
    if [ -z "$DELETED_FILES" ]; then
        echo "✅ 檢查完畢：沒有需要清理的過期照片。" >> $LOG_FILE
    else
        echo "🗑️ 已清理以下過期照片：" >> $LOG_FILE
        echo "$DELETED_FILES" >> $LOG_FILE
    fi
else
    echo "⚠️ 錯誤：找不到存儲目錄 $STORAGE_DIR" >> $LOG_FILE
fi
echo "=====================================" >> $LOG_FILE
