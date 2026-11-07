import os

file_path = "backend/app/routers/devices.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 如果找不到 OTA_DIR 的定義，就強制寫入到 router 定義的前面
if "OTA_DIR = " not in content and "OTA_DIR=" not in content:
    insert_code = """
# ===== 強制寫入 OTA 資料夾定義 =====
import os
OTA_DIR = "/tmp/aegis_ota"
os.makedirs(OTA_DIR, exist_ok=True)
# ===================================

"""
    # 找到 router 宣告的位置，在它前面插入
    idx = content.find("router = APIRouter")
    if idx != -1:
        new_content = content[:idx] + insert_code + content[idx:]
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("✅ 成功！已使用強制插入法定義 OTA_DIR。")
    else:
        print("❌ 找不到 router 定義！")
else:
    print("⚡ OTA_DIR 已經存在，無需修改。")
