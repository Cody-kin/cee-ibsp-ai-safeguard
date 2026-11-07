import os

file_path = "backend/app/main.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 修正儲存邏輯：根據鏡頭 ID (cam_id) 儲存獨立檔案
old_code = 'with open(f"storage/latest_{device_id}.jpg", "wb") as f:'
new_code = 'with open(f"storage/latest_{device_id}_{cam_id}.jpg", "wb") as f:'

if old_code in content:
    content = content.replace(old_code, new_code)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("✅ 後端影像儲存邏輯已更新為多鏡頭模式！")
else:
    print("⚠️ 找不到舊代碼，可能已經修改過。")

# 確保 storage 資料夾權限正確
os.system("mkdir -p backend/storage && chmod 777 backend/storage")
