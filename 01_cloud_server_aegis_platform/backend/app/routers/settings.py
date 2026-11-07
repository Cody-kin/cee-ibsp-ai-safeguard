import os
import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from ..database import get_db
from .. import models
from ..deps import get_current_user

router = APIRouter(prefix="/api/v1", tags=["Settings & Users"])
STORAGE_DIR = "storage"
SETTINGS_FILE = os.path.join(STORAGE_DIR, "system_settings.json")

# --- 1. 系統自動保留天數設定 ---
def get_retention_days():
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r") as f:
                return json.load(f).get("retention_days", 7)
        except: pass
    return 7

def set_retention_days(days: int):
    with open(SETTINGS_FILE, "w") as f:
        json.dump({"retention_days": days}, f)

class SettingsUpdate(BaseModel):
    retention_days: int

@router.get("/settings")
def get_settings(current_user: models.User = Depends(get_current_user)):
    return {"status": "success", "retention_days": get_retention_days()}

@router.post("/settings")
def update_settings(settings: SettingsUpdate, current_user: models.User = Depends(get_current_user)):
    set_retention_days(settings.retention_days)
    return {"status": "success", "message": "Settings updated"}

# --- 2. 資料庫一鍵清空 ---
@router.delete("/events")
def clear_all_events(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(models.Event).delete()
    db.commit()
    for filename in os.listdir(STORAGE_DIR):
        if filename.startswith("evt_"):
            try: os.remove(os.path.join(STORAGE_DIR, filename))
            except: pass
    return {"status": "success", "message": "所有事件與歷史照片已清空！"}

# --- 3. 👥 用戶管理 API ---
@router.get("/users")
def get_all_users(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    # 確保只有 admin 可以看用戶名單
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="權限不足")
    users = db.query(models.User).all()
    return {"status": "success", "data": [{"id": u.id, "email": u.email, "role": u.role} for u in users]}

@router.delete("/users/{user_id}")
def delete_user(user_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="權限不足")
    if current_user.id == user_id:
        raise HTTPException(status_code=400, detail="不能刪除自己！")
    
    user_to_delete = db.query(models.User).filter(models.User.id == user_id).first()
    if not user_to_delete:
        raise HTTPException(status_code=404, detail="找不到該用戶")
        
    db.delete(user_to_delete)
    db.commit()
    return {"status": "success", "message": f"用戶 {user_to_delete.email} 已刪除"}
