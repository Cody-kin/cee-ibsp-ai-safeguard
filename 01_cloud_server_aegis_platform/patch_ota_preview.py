import os

file_path = "backend/app/routers/devices.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

new_apis = """
@router.get("/ota/files/{filename}/content")
def get_ota_file_content(filename: str):
    path = f"{OTA_DIR}/{filename}"
    if os.path.exists(path) and filename.endswith(('.sh', '.json', '.txt', '.py')):
        with open(path, "r", encoding="utf-8") as f:
            return {"status": "success", "content": f.read()}
    raise HTTPException(status_code=404, detail="File not found or not readable text")

@router.delete("/ota/files")
def clear_all_ota_files():
    if os.path.exists(OTA_DIR):
        for f in os.listdir(OTA_DIR):
            os.remove(f"{OTA_DIR}/{f}")
    return {"status": "success"}
"""

if "/ota/files/{filename}/content" not in content:
    content += new_apis
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("✅ OTA 預覽與清空 API 植入成功！")
