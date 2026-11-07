import os
import re

file_path = "backend/app/routers/events.py"

if not os.path.exists(file_path):
    print(f"❌ 找不到檔案: {file_path}")
    exit(1)

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. 替換 FastAPI 參數預設值 (例如: limit: int = 100)
content = re.sub(r'limit\s*:\s*int\s*=\s*100', 'limit: int = 5000', content)

# 2. 替換純等號參數 (例如: limit=100)
content = re.sub(r'limit\s*=\s*100\b', 'limit=5000', content)

# 3. 替換資料庫 ORM 語法 (例如: .limit(100))
content = re.sub(r'\.limit\(\s*100\s*\)', '.limit(5000)', content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ events.py 封印解除！已將上限提升至 5000 筆！")
