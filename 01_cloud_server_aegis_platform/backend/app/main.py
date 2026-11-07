from .core.validation import safe_identifier
import os, shutil, time, threading, json
import urllib.request
import urllib.parse
from fastapi import FastAPI, Depends, HTTPException, status, File, UploadFile, Form
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from datetime import datetime, timedelta

from .database import engine, Base, get_db, SessionLocal
from . import models
from .core.security import verify_password, get_password_hash, create_access_token
from .deps import get_current_user
from .routers import analysis, users

models.Base.metadata.create_all(bind=engine)
app = FastAPI(title="AI-SafeGuard API")

STORAGE_DIR = "storage"
SETTINGS_FILE = os.path.join(STORAGE_DIR, "system_settings.json")
os.makedirs(STORAGE_DIR, exist_ok=True)
app.mount("/storage", StaticFiles(directory=STORAGE_DIR), name="storage")

app.include_router(analysis.router)
app.include_router(users.router)

# 🌟 Telegram Bot 設定
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

def send_telegram_alert(message: str):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID: return
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    data = urllib.parse.urlencode({'chat_id': TELEGRAM_CHAT_ID, 'text': message, 'parse_mode': 'Markdown'}).encode('utf-8')
    try:
        req = urllib.request.Request(url, data=data)
        urllib.request.urlopen(req, timeout=5)
    except Exception as e:
        print(f"Telegram alert failed: {e}")

# 🌟 補上的：讀取與寫入保留天數功能
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
    retention_days: int = Field(ge=1, le=3650)

# 🌟 升級版看門狗：現在會根據你的設定天數自動刪除資料了
OFFLINE_TIMEOUT = 120 
def invincible_watchdog():
    while True:
        try:
            now = time.time()
            days = get_retention_days() # 動態讀取天數
            retention_seconds = days * 24 * 60 * 60
            for filename in os.listdir(STORAGE_DIR):
                file_path = os.path.join(STORAGE_DIR, filename)
                if not os.path.isfile(file_path) or filename.endswith(".json"): continue
                mtime = os.stat(file_path).st_mtime
                if filename.startswith("latest_"):
                    if now - mtime > OFFLINE_TIMEOUT: os.remove(file_path)
                else:
                    if now - mtime > retention_seconds: os.remove(file_path)
            db = SessionLocal()
            try:
                cutoff_time = datetime.utcnow() - timedelta(days=days) # 動態讀取天數
                db.query(models.Event).filter(models.Event.timestamp < cutoff_time).delete(synchronize_session=False)
                db.commit()
            except Exception: pass
            finally: db.close()
        except Exception: pass
        time.sleep(3600)

def init_db():
    db = next(get_db())
    if not db.query(models.User).filter(models.User.username == "admin").first():
        db.add(models.User(username="admin", hashed_password=get_password_hash(os.environ["INITIAL_ADMIN_PASSWORD"]), role="admin"))
    db.commit()
    db.close()

@app.on_event("startup")
def on_startup():
    init_db()
    if os.getenv("ENABLE_BACKGROUND_TASKS", "1") == "1":
        threading.Thread(target=invincible_watchdog, daemon=True).start()

class PublicUserRegister(BaseModel):
    username: str
    password: str

@app.post("/api/v1/auth/register")
def register_public(user: PublicUserRegister, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.username == user.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")
    new_user = models.User(username=user.username, hashed_password=get_password_hash(user.password), role="user")
    db.add(new_user)
    db.commit()
    return {"status": "success"}

@app.post("/api/v1/auth/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"access_token": create_access_token(data={"sub": user.username, "role": user.role}), "token_type": "bearer", "role": user.role}

# 🌟 補上的：前端呼叫的設定 API (GET 與 POST)
@app.get("/api/v1/settings")
def get_settings_api(current_user: models.User = Depends(get_current_user)):
    return {"status": "success", "retention_days": get_retention_days()}

@app.post("/api/v1/settings")
def update_settings_api(settings: SettingsUpdate, current_user: models.User = Depends(get_current_user)):
    if current_user.role != "admin": 
        raise HTTPException(status_code=403, detail="Permission denied")
    set_retention_days(settings.retention_days)
    return {"status": "success", "message": "Settings updated"}

@app.post("/api/v1/events", status_code=status.HTTP_201_CREATED)
async def create_event(device_id: str = Form(...), event_type: str = Form(...), event_name: str = Form(...), severity: str = Form(...), description: str = Form(...), image: UploadFile = File(None), db: Session = Depends(get_db)):
    safe_identifier(device_id)
    safe_identifier(event_type)
    # --- 3秒去重與智慧補圖邏輯 (開始) ---
    global RECENT_EVENTS_CACHE
    if 'RECENT_EVENTS_CACHE' not in globals():
        RECENT_EVENTS_CACHE = {}
        
    fingerprint = f"{device_id}_{event_type}_{event_name}"
    import time
    current_time = time.time()
    
    if fingerprint in RECENT_EVENTS_CACHE and (current_time - RECENT_EVENTS_CACHE[fingerprint] < 3.0):
        if image:
            temp_path = os.path.join(STORAGE_DIR, f"temp_{device_id}.jpg")
            latest_path = os.path.join(STORAGE_DIR, f"latest_{device_id}.jpg")
            with open(temp_path, "wb") as buffer: shutil.copyfileobj(image.file, buffer)
            os.replace(temp_path, latest_path)
        return {"status": "success", "message": "Duplicate event intercepted"}
        
    RECENT_EVENTS_CACHE[fingerprint] = current_time
    # --- 3秒去重與智慧補圖邏輯 (結束) ---

    now = datetime.utcnow()
    new_event_id = None
    e_type_lower = event_type.lower()
    e_name_lower = event_name.lower()
    is_stream = ("stream" in e_type_lower or "stream" in e_name_lower)

    hb = db.query(models.Event).filter(models.Event.device_id == device_id, models.Event.event_type == "system_heartbeat").first()
    if hb:
        hb.timestamp = now
        db.commit()
    else:
        hb_event = models.Event(device_id=device_id, event_type="system_heartbeat", event_name="Heartbeat", severity="info", description="", timestamp=now)
        db.add(hb_event)
        db.commit()

    should_insert = True
    if is_stream:
        last_stream = db.query(models.Event).filter(
            models.Event.device_id == device_id,
            models.Event.event_type == event_type
        ).order_by(models.Event.timestamp.desc()).first()
        if last_stream and (now - last_stream.timestamp).total_seconds() < 120:
            should_insert = False 

    if should_insert:
        final_severity = "info" if is_stream else severity
        new_event = models.Event(device_id=device_id, event_type=event_type, event_name=event_name, severity=final_severity, description=description, timestamp=now)
        db.add(new_event)
        db.commit()
        db.refresh(new_event)
        new_event_id = new_event.id
        
        if final_severity in ["critical", "high"] and not is_stream:
            alert_msg = f"🚨 *【AI-SafeGuard 警報】*\n\n"
            alert_msg += f"📍 *設備*: `{device_id}`\n"
            alert_msg += f"⚠️ *事件*: {event_name}\n"
            alert_msg += f"📝 *描述*: {description}\n"
            alert_msg += f"🕒 *時間*: {now.strftime('%Y-%m-%d %H:%M:%S')} (UTC)\n\n"
            alert_msg += f"請立即登入系統確認狀況！"
            threading.Thread(target=send_telegram_alert, args=(alert_msg,), daemon=True).start()
    
    if image:
        temp_path = os.path.join(STORAGE_DIR, f"temp_{device_id}.jpg")
        latest_path = os.path.join(STORAGE_DIR, f"latest_{device_id}.jpg")
        with open(temp_path, "wb") as buffer: shutil.copyfileobj(image.file, buffer)
        os.replace(temp_path, latest_path)
        os.utime(latest_path, None)
        if new_event_id and not is_stream: 
            shutil.copy(latest_path, os.path.join(STORAGE_DIR, f"evt_{new_event_id}_{event_type}.jpg"))

    return {"status": "success"}

@app.get("/api/v1/events")
def get_events(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    events = db.query(models.Event).order_by(models.Event.timestamp.desc()).limit(5000).all()
    data = []
    for e in events:
        img_exists = os.path.exists(os.path.join(STORAGE_DIR, f"evt_{e.id}_{e.event_type}.jpg"))
        data.append({
            "id": e.id, "device_id": e.device_id, "event_type": e.event_type, 
            "event_name": e.event_name, "severity": e.severity, "description": e.description, 
            "timestamp": e.timestamp.isoformat(), "has_image": img_exists
        })
    return {"status": "success", "data": data}

@app.post("/api/v1/events/reset")
def reset_safety_status(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    cutoff_time = datetime.utcnow() - timedelta(minutes=15)
    recent_criticals = db.query(models.Event).filter(
        models.Event.timestamp >= cutoff_time,
        models.Event.severity.in_(["critical", "high", "warning"])
    ).all()
    count = 0
    for evt in recent_criticals:
        evt.severity = "info" 
        if not evt.description.startswith("[RESOLVED]"):
            evt.description = f"[RESOLVED by {current_user.username}] " + evt.description
        count += 1
    db.commit()
    return {"status": "success", "message": f"Successfully resolved {count} active alerts."}

@app.delete("/api/v1/events/clear")
def clear_all_events(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin": raise HTTPException(status_code=403, detail="Permission denied")
    try:
        db.execute(text("DELETE FROM events"))
        db.commit()
        for filename in os.listdir(STORAGE_DIR):
            if filename.endswith(".jpg") and not filename.startswith("latest_"):
                try: os.remove(os.path.join(STORAGE_DIR, filename))
                except Exception: pass
        return {"status": "success", "message": "All events and images cleared"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"DB Error: {str(e)}")


# --- 動態分流路由 (動態修復) ---
try:
    from app.routers import devices
except ImportError:
    from routers import devices
app.include_router(devices.router)

# LoRaWAN ChirpStack HTTP Integration + Node2 compatible adapter
try:
    from app.routers import lorawan
except ImportError:
    from routers import lorawan
app.include_router(lorawan.router)
