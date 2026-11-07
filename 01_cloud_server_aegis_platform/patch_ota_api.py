import os

file_path = "backend/app/routers/devices.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. 確保引入 File 和 UploadFile
if "from fastapi import File, UploadFile" not in content:
    content = content.replace("from fastapi import APIRouter, Request", "from fastapi import APIRouter, Request, File, UploadFile")

# 2. 新增 OTA 管理 API (上傳、列表、刪除)
new_apis = """
@router.post("/ota/upload")
async def upload_ota_file(file: UploadFile = File(...)):
    file_path = f"{OTA_DIR}/{file.filename}"
    with open(file_path, "wb") as f:
        f.write(await file.read())
    return {"status": "success", "filename": file.filename}

@router.get("/ota/files")
def list_ota_files():
    files = []
    if os.path.exists(OTA_DIR):
        for f in os.listdir(OTA_DIR):
            path = f"{OTA_DIR}/{f}"
            if os.path.isfile(path):
                stat = os.stat(path)
                files.append({"name": f, "size": stat.st_size, "modified": stat.st_mtime})
    # 依修改時間排序，最新的在前面
    files.sort(key=lambda x: x['modified'], reverse=True)
    return {"status": "success", "data": files}

@router.delete("/ota/files/{filename}")
def delete_ota_file(filename: str):
    path = f"{OTA_DIR}/{filename}"
    if os.path.exists(path):
        os.remove(path)
        return {"status": "success"}
    raise HTTPException(status_code=404, detail="File not found")
"""

if "@router.post(\"/ota/upload\")" not in content:
    content += new_apis
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("✅ OTA 檔案管理 API 植入成功！")
else:
    print("⚡ API 已存在，跳過植入。")
