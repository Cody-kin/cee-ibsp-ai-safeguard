import os

file_path = "backend/app/routers/devices.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 強制在 router 宣告的正下方，插入變數定義與建立資料夾的指令
if "OTA_DIR =" not in content and "OTA_DIR=" not in content:
    target_str = 'router = APIRouter(prefix="/api/v1", tags=["Devices"])'
    insert_str = "\n# 確保 OTA 資料夾存在\nOTA_DIR = '/tmp/aegis_ota'\nos.makedirs(OTA_DIR, exist_ok=True)\n"
    
    if target_str in content:
        content = content.replace(target_str, target_str + insert_str)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("✅ 成功補上致命缺失的 OTA_DIR 變數！")
    else:
        print("❌ 找不到 router 宣告，可能檔案結構已被大幅修改。")
else:
    print("⚡ OTA_DIR 已經存在，無需修改。")
