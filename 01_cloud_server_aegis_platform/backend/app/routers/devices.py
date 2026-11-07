from ..deps import require_admin
from ..core.validation import safe_identifier
from pydantic import BaseModel
from fastapi import Depends, APIRouter, Request, File, UploadFile, HTTPException, Response
import time
import os
import json

router = APIRouter(prefix="/api/v1", tags=["Devices"])
# 確保 OTA 資料夾存在
OTA_DIR = '/tmp/aegis_ota'
os.makedirs(OTA_DIR, exist_ok=True)


FRAME_DIR = "/tmp/aegis_frames"
CONFIG_DIR = "/tmp/aegis_configs"
HEARTBEAT_DIR = "/tmp/aegis_heartbeats"
LORA_CMD_DIR = "/tmp/aegis_lora_cmds"
for d in [FRAME_DIR, CONFIG_DIR, HEARTBEAT_DIR, LORA_CMD_DIR]:
    os.makedirs(d, exist_ok=True)

def get_config(device_id):
    safe_identifier(device_id)
    path = f"{CONFIG_DIR}/{device_id}.json"
    if os.path.exists(path):
        try:
            with open(path, "r") as f: return json.load(f)
        except: pass
    return {
        "fire": 0.45, "smoke": 0.35, "fall": 0.45, 
        "hardhat": 0.0, "vest": 0.0, "smoking": 0.0, "phone": 0.0, 
        "assignees": ["admin"]
    }

def save_config(device_id, config):
    safe_identifier(device_id)
    with open(f"{CONFIG_DIR}/{device_id}.json", "w") as f: json.dump(config, f)

def touch_heartbeat(device_id):
    safe_identifier(device_id)
    with open(f"{HEARTBEAT_DIR}/{device_id}.time", "w") as f: f.write(str(time.time()))

def get_device_status(device_id, timeout_seconds=15):
    current_time = time.time()
    path = f"{HEARTBEAT_DIR}/{device_id}.time"
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                last_seen = float(f.read())
            if current_time - last_seen < timeout_seconds:
                return "online"
        except: pass

    if device_id == "NANO-001":
        for file in os.listdir(FRAME_DIR):
            if file.startswith("NANO-001") and file.endswith(".time"):
                try:
                    with open(f"{FRAME_DIR}/{file}", "r") as f:
                        last_seen = float(f.read())
                    if current_time - last_seen < timeout_seconds:
                        return "online"
                except: pass
                
    return "offline"

def queue_lora_command(cam_full_id, config):
    cam_short = cam_full_id.split('_', 1)[-1] if '_' in cam_full_id else cam_full_id
    keys = ["fire", "smoke", "fall", "hardhat", "vest", "smoking", "phone"]
    flags = [f"{float(config.get(k, 0.0)):.2f}" for k in keys]
    cmd = f"CFG|{cam_short}|{','.join(flags)}\n"
    with open(f"{LORA_CMD_DIR}/pending.txt", "w") as f: f.write(cmd)

@router.post("/heartbeat")
async def handle_heartbeat(request: Request):
    try:
        data = await request.json()
        device_id = data.get("device_id", "NANO-001")
        cameras = data.get("cameras", ["cam_0", "cam_1"])
        touch_heartbeat(device_id) 
        response_data = {}
        for cam in cameras:
            ui_config = get_config(f"{device_id}_{cam}")

            # Return full threshold config, not only active model names.
            # This allows Nano to dynamically apply sensitivity values.
            cam_thresholds = {}
            for k, v in ui_config.items():
                if k == "assignees":
                    continue
                try:
                    cam_thresholds[k] = float(v)
                except Exception:
                    pass

            response_data[cam] = cam_thresholds
        return response_data
    except: return {}

@router.post("/stream/{device_id}/{camera_id}")
async def upload_stream(device_id: str, camera_id: str, request: Request):
    safe_identifier(camera_id)
    safe_identifier(device_id)
    body = await request.body()
    if len(body) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Frame too large")
    if not body: return {"status": "error"}
    file_path = f"{FRAME_DIR}/{device_id}_{camera_id}.jpg"
    with open(file_path, "wb") as f: f.write(body)
    with open(f"{file_path}.time", "w") as f: f.write(str(time.time()))
    return {"status": "success"}

@router.get("/stream/{device_id}/{camera_id}")
def get_stream(device_id: str, camera_id: str):
    safe_identifier(camera_id)
    safe_identifier(device_id)
    file_path = f"{FRAME_DIR}/{device_id}_{camera_id}.jpg"
    if os.path.exists(file_path):
        try:
            with open(file_path, "rb") as f: frame = f.read()
            if len(frame) > 1000: return Response(content=frame, media_type="image/jpeg")
        except: pass
    raise HTTPException(status_code=404, detail="Image not ready")

@router.get("/devices")
def list_devices():
    devices = [
        {"id": "NANO-001", "name": "Jetson Nano AI 主機", "type": "host", "status": get_device_status("NANO-001")},
        {"id": "LORA-001", "name": "LoRa 緊急通訊網關", "type": "gateway", "status": get_device_status("LORA-001")}
    ]
    current_time = time.time()
    for file in os.listdir(FRAME_DIR):
        if file.endswith(".time"):
            cam_full_id = file.replace(".jpg.time", "")
            try:
                with open(f"{FRAME_DIR}/{file}", "r") as f: last_seen = float(f.read())
                if current_time - last_seen < 15:
                    parts = cam_full_id.split("_", 1)
                    if len(parts) == 2:
                        dev_id, cam_id = parts
                        devices.append({
                            "id": cam_full_id,
                            "name": f"AI 監控鏡頭 ({cam_id.upper()})",
                            "type": "camera",
                            "stream_url": f"/api/v1/stream/{dev_id}/{cam_id}",
                            "config": get_config(cam_full_id)
                        })
            except: pass
    return {"status": "success", "data": devices}

@router.put("/devices/{camera_id}/config", dependencies=[Depends(require_admin)])
async def update_device_config(camera_id: str, request: Request):
    config = await request.json()
    save_config(camera_id, config)
    queue_lora_command(camera_id, config)
    return {"status": "success"}

@router.get("/lora/commands")
def get_lora_commands():
    touch_heartbeat("LORA-001") 
    cmd_path = f"{LORA_CMD_DIR}/pending.txt"
    if os.path.exists(cmd_path):
        with open(cmd_path, "r") as f: cmd = f.read().strip()
        os.remove(cmd_path)
        return {"status": "success", "command": cmd}
    return {"status": "success", "command": None}

# 🌟 絕對精準的遙控路由，對應網頁前端的 /api/v1/devices/NANO-001/system_command


class SysCmd(BaseModel):
    command: str

@router.post("/devices/{device_id}/system_command", dependencies=[Depends(require_admin)])
async def send_system_command(device_id: str, cmd_data: SysCmd):
    if cmd_data.command in ["START", "STOP", "OTA_SCRIPT"]:
        cmd_str = f"SYS|{cmd_data.command}\n"
        with open(f"{LORA_CMD_DIR}/pending.txt", "w") as f_out:
            f_out.write(cmd_str)
        return {"status": "success", "message": "Command queued"}
    return {"status": "error", "message": "Invalid command"}

@router.post("/ota/upload", dependencies=[Depends(require_admin)])
async def upload_ota_file(file: UploadFile = File(...)):
    safe_identifier(file.filename)
    file_path = f"{OTA_DIR}/{file.filename}"
    with open(file_path, "wb") as f:
        f.write(await file.read())
    return {"status": "success", "filename": file.filename}

@router.get("/ota/files", dependencies=[Depends(require_admin)])
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

@router.delete("/ota/files/{filename}", dependencies=[Depends(require_admin)])
def delete_ota_file(filename: str):
    safe_identifier(filename)
    path = f"{OTA_DIR}/{filename}"
    if os.path.exists(path):
        os.remove(path)
        return {"status": "success"}
    raise HTTPException(status_code=404, detail="File not found")

@router.get("/ota/files/{filename}/content", dependencies=[Depends(require_admin)])
def get_ota_file_content(filename: str):
    safe_identifier(filename)
    path = f"{OTA_DIR}/{filename}"
    if os.path.exists(path) and filename.endswith(('.sh', '.json', '.txt', '.py')):
        with open(path, "r", encoding="utf-8") as f:
            return {"status": "success", "content": f.read()}
    raise HTTPException(status_code=404, detail="File not found or not readable text")

@router.delete("/ota/files", dependencies=[Depends(require_admin)])
def clear_all_ota_files():
    if os.path.exists(OTA_DIR):
        for f in os.listdir(OTA_DIR):
            os.remove(f"{OTA_DIR}/{f}")
    return {"status": "success"}

from fastapi.responses import FileResponse

@router.get("/ota/{filename}")
def download_ota_file(filename: str):
    safe_identifier(filename)
    """提供給 Nano 端 wget 直接下載檔案的路由"""
    path = f"{OTA_DIR}/{filename}"
    if os.path.exists(path):
        return FileResponse(path)
    raise HTTPException(status_code=404, detail="File not found")
