import os

file_path = "frontend/src/app/page.tsx"

if not os.path.exists(file_path):
    print(f"❌ 找不到檔案: {file_path}")
    exit(1)

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. 替換標題文字
content = content.replace("'Total Events' : '總事件數'", "'Today\\'s Events' : '今日事件數'")
content = content.replace("<br/>(24h)", "<br/>(Today)")

# 2. 替換顯示的變數 (只替換那張大卡片裡的 allEvents 變成 todaysEvents)
old_div = '<div className="text-4xl font-black text-white tracking-tight">{allEvents.length}</div>'
new_div = '<div className="text-4xl font-black text-white tracking-tight">{todaysEvents.length}</div>'
content = content.replace(old_div, new_div)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ UI 文字與變數替換完成！")
