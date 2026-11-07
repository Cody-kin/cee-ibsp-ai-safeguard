#!/bin/bash
echo "🚀 啟動 AI-SafeGuard (工業級守護進程模式)"
echo "💡 提示：若要徹底關閉程式，請在終端機按 Ctrl+C"
echo "------------------------------------------------"

while true; do
    # 執行你的主程式
    python3 main.py
    
    # 獲取 Python 程式的退出狀態碼
    EXIT_CODE=$?
    
    # 狀態碼 130 代表使用者手動按了 Ctrl+C
    if [ $EXIT_CODE -eq 130 ]; then
        echo ""
        echo "🛑 收到手動中止訊號 (Ctrl+C)，守護進程安全退出。"
        break
    fi
    
    # 其他情況 (包含 OTA 更新的正常退出 0) 則執行自動重啟
    echo "🔄 偵測到程式結束 (退出碼: $EXIT_CODE)，硬體資源已釋放。"
    echo "⏳ 2 秒後自動喚醒系統..."
    sleep 2
done
