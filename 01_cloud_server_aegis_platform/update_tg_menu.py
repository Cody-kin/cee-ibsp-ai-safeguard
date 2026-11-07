import os
import requests

BOT_TOKEN = os.getenv("BOT_TOKEN", "")

# 加入滿滿的 Emoji 讓選單重返榮耀 ✨
commands = [
    {"command": "status", "description": "📊 數據與雙鏡頭狀態回報"},
    {"command": "snapshot", "description": "📸 擷取現場即時快照"},
    {"command": "calibrate", "description": "🎯 氣體感測器基準校準"},
    {"command": "grant", "description": "🔑 指派系統管理權限"}
]

print("⚙️ 正在向 Telegram 傳送美化版選單...")
r = requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/setMyCommands", json={"commands": commands})

if r.status_code == 200:
    print("✅ TG 選單更新成功！趕快打開手機看看！")
else:
    print(f"❌ 更新失敗: {r.text}")
