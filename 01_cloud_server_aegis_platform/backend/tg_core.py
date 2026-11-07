import os, time, requests, sys
from email.utils import parsedate_to_datetime
from datetime import datetime, timezone, timedelta

BOT_TOKEN = os.getenv("BOT_TOKEN", "")
CHAT_ID = os.getenv("CHAT_ID", "")
ADMIN_USER, ADMIN_PASS = "admin", "Admin123!"
LOCAL_API_URL = "http://127.0.0.1/api/v1"
TW_TZ = timezone(timedelta(hours=8))

last_update_id, last_event_id = 0, 0
BASELINE_FILE = "tg_mq2_baseline.txt"

def get_baseline():
    try: return int(open(BASELINE_FILE, "r").read().strip())
    except: return 0

def set_baseline(val):
    with open(BASELINE_FILE, "w") as f: f.write(str(val))

def get_token():
    try:
        r = requests.post(f"{LOCAL_API_URL}/auth/login", data={"username": ADMIN_USER, "password": ADMIN_PASS}, timeout=3)
        return r.json().get("access_token") if r.status_code == 200 else None
    except: return None

def send_tg(text, photo_path=None, target_chat_id=None):
    cid = target_chat_id if target_chat_id else CHAT_ID
    try:
        data = {"chat_id": cid, "parse_mode": "HTML"} 
        if photo_path and os.path.exists(photo_path):
            data["caption"] = text
            with open(photo_path, "rb") as f: 
                r = requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto", data=data, files={"photo": f}, timeout=10)
        else:
            data["text"] = text
            r = requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage", json=data, timeout=5)
            
        if r.status_code != 200:
            print(f"⚠️ TG API 拒絕發送 (HTTP {r.status_code}): {r.text}", flush=True)
            
    except Exception as e: 
        print(f"Send TG Error: {e}", flush=True)

def check_online_status(e_list, srv_ts):
    if not e_list: return False, "🔴 離線 (無資料)"
    ts_str = e_list[-1].get("timestamp", "")
    try:
        clean_str = ts_str.replace("T", " ").replace("Z", "")[:19]
        dt = datetime.strptime(clean_str, "%Y-%m-%d %H:%M:%S")
        e_ts = dt.replace(tzinfo=timezone.utc).timestamp()
        is_online = abs(srv_ts - e_ts) <= 150
        return is_online, "🟢 在線" if is_online else "🔴 離線"
    except: return False, "🔴 離線 (解析異常)"

def get_ai_summary(nano_online, lora_online, mq2_val, critical_count, sys_mode):
    if not nano_online and not lora_online:
        return "🚨 <b>重大警報：全系統失去聯繫。</b> 請立刻檢查基站電源與網路環境。"
    if sys_mode == "sleep":
        return "💤 <b>系統目前處於深度待命模式 (OTA/休眠中)</b>，AI 視覺防護已暫停。"
        
    status_msg = "✅ 目前環境看起來很安全。"
    if mq2_val > 400:
        status_msg = "⚠️ <b>偵測到異常煙霧數值！</b> 建議檢查是否有悶燒現象。"
    elif mq2_val > 150:
        status_msg = "💡 環境有輕微波動，建議持續觀察。"
    if not nano_online:
        status_msg += "\n⚠️ 注意：視覺節點 (Nano) 處於離線狀態，無法進行人臉或火災視覺分析。"
    if critical_count > 0:
        status_msg = f"🛑 <b>系統處於緊急狀態！</b> 最近偵測到 {critical_count} 筆危險事件，請立即查看快照！"
    return status_msg

print("🤖 AI-SafeGuard 戰術終端機啟動中...", flush=True)

# 🌟 新增：向 Telegram 註冊最新的指令選單
try:
    print("⚙️ 正在向 Telegram 註冊指令選單...", flush=True)
    commands = [
        {"command": "status", "description": "數據與雙鏡頭回報"},
        {"command": "snapshot", "description": "即時快照"},
        {"command": "calibrate", "description": "校準 MQ2"},
        {"command": "grant", "description": "權限指派 (限管理員)"}
    ]
    requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/setMyCommands", json={"commands": commands}, timeout=5)
    print("✅ 指令選單註冊完成！", flush=True)
except Exception as e:
    print(f"⚠️ 指令選單註冊失敗: {e}", flush=True)

try:
    print("🔄 正在同步雲端歷史資料...", flush=True)
    init_token = get_token()
    if init_token:
        init_res = requests.get(f"{LOCAL_API_URL}/events", headers={"Authorization": f"Bearer {init_token}"}, timeout=5)
        init_evts = init_res.json().get("data", [])
        if init_evts:
            last_event_id = max(e.get("id", 0) for e in init_evts)
            print(f"✅ 同步完成！已忽略歷史警報。監聽起始點: ID {last_event_id}", flush=True)
except Exception as e:
    print(f"⚠️ 初始化同步失敗，將從 0 開始: {e}", flush=True)


while True:
    token = get_token()
    if not token: 
        time.sleep(5)
        continue
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        upd = requests.get(f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates", params={"offset": last_update_id+1, "timeout": 5}).json()
        for u in upd.get("result", []):
            last_update_id = u.get("update_id", last_update_id)
            msg = u.get("message", {}).get("text", "")
            sender_id = str(u.get("message", {}).get("chat", {}).get("id", ""))
            
            if not msg: continue
            print(f"📥 收到指令: {msg} (發送者: {sender_id})", flush=True)
            
            res = requests.get(f"{LOCAL_API_URL}/events", headers=headers)
            srv_ts = parsedate_to_datetime(res.headers.get('Date')).timestamp() if res.headers.get('Date') else datetime.now().timestamp()
            evts = res.json().get("data", [])
            evts.sort(key=lambda x: x.get("id", 0))
            
            nano_evts = [e for e in evts if e.get("device_id") == "DEV-NANO-001" or e.get("event_type") == "system_heartbeat"]
            lora_evts = [e for e in evts if e.get("event_type") == "sensor"]
            nano_ok, nano_str = check_online_status(nano_evts, srv_ts)
            lora_ok, lora_str = check_online_status(lora_evts, srv_ts)

            sys_mode = "active"
            for e in evts[-15:]:
                if e.get("event_type") == "system_log" and "Sleep" in e.get("event_name", ""):
                    sys_mode = "sleep"
                elif e.get("event_type") == "system_log" and ("Ready" in e.get("event_name", "") or "Success" in e.get("event_name", "")):
                    sys_mode = "active"

            if msg.startswith("/start"):
                send_tg("👋 <b>AI-SafeGuard 智慧管家</b>\n\n指令：\n/status - 數據與雙鏡頭回報\n/snapshot - 即時快照\n/calibrate [值] - 校準 MQ2\n/grant [帳號] [角色] - 權限指派", target_chat_id=sender_id)

            elif msg.startswith("/calibrate"):
                try:
                    val = int(msg.split()[1]); set_baseline(val)
                    send_tg(f"🎯 <b>MQ2 基準已歸校為: {val}</b>", target_chat_id=sender_id)
                except: send_tg("ℹ️ 請輸入 <code>/calibrate 500</code> 格式", target_chat_id=sender_id)

            elif msg in ["/status", "/report"]:
                baseline = get_baseline()
                mq2_val, raw_mq2, mq3_val = 0, 0, 0
                if lora_evts and "[Gas:" in lora_evts[-1].get("description", ""):
                    try:
                        parts = lora_evts[-1].get("description", "").split("[Gas:")[1].split("]")[0].split("/")
                        raw_mq2 = int(parts[0])
                        mq2_val = max(0, raw_mq2 - baseline)
                        mq3_val = int(parts[1]) if len(parts) > 1 else 0
                    except: pass
                
                recent_critical = len([e for e in evts[-10:] if e.get("severity") == "critical"])
                ai_text = get_ai_summary(nano_ok, lora_ok, mq2_val, recent_critical, sys_mode)
                
                cam0_status = "🟢 在線 (AI 分析中)" if nano_ok and sys_mode == "active" else ("💤 待命中" if sys_mode == "sleep" else "🔴 離線")
                cam1_status = "🟢 在線 (AI 分析中)" if nano_ok and sys_mode == "active" else ("💤 待命中" if sys_mode == "sleep" else "🔴 離線")
                
                tw_now = datetime.now(TW_TZ).strftime("%H:%M:%S")
                report = (
                    f"📊 <b>AI-SafeGuard 系統報告</b> [{tw_now}]\n\n"
                    f"🤖 <b>邊緣 AI 診斷：</b>\n&gt; {ai_text}\n\n"
                    f"📡 <b>節點與鏡頭狀態：</b>\n"
                    f"- 🌐 LoRa 網關: {lora_str}\n"
                    f"- 🎥 Cam_0 (主通道): {cam0_status}\n"
                    f"- 🎥 Cam_1 (盲區): {cam1_status}\n\n"
                    f"🌡️ <b>即時數據 (校準後)：</b>\n"
                    f"- 💨 MQ2: <code>{mq2_val} ppm</code> (原:{raw_mq2})\n"
                    f"- 🍷 MQ3: <code>{mq3_val} ppm</code>"
                )
                send_tg(report, target_chat_id=sender_id)

            elif msg == "/snapshot":
                if not nano_ok:
                    send_tg("❌ <b>擷取失敗</b>\n原因：Vision Node 目前處於<b>離線狀態</b>。", target_chat_id=sender_id)
                elif sys_mode == "sleep":
                    send_tg("⚠️ <b>擷取失敗</b>\n原因：設備目前處於<b>待命模式</b>，相機已關閉。", target_chat_id=sender_id)
                else:
                    send_tg("📸 <b>正在擷取現場即時畫面...</b>", target_chat_id=sender_id)
                    
                    # 🌟 智能雙重探測：因為不知道後端是用 NANO-001 還是 DEV-NANO-001 存檔，兩個都找！
                    urls_to_try = [
                        "http://127.0.0.1/storage/latest_NANO-001.jpg",
                        "http://127.0.0.1/storage/latest_DEV-NANO-001.jpg"
                    ]
                    
                    success = False
                    for img_url in urls_to_try:
                        try:
                            r = requests.get(f"{img_url}?t={int(time.time())}", timeout=5)
                            if r.status_code == 200:
                                tmp_path = "/tmp/tg_snap.jpg"
                                with open(tmp_path, "wb") as f: f.write(r.content)
                                send_tg("📍 AI-SafeGuard 即時現場畫面\n(註：此為最後上傳之鏡頭畫面)", tmp_path, target_chat_id=sender_id)
                                success = True
                                break # 找到一張就跳出迴圈
                        except: pass
                        
                    if not success:
                        send_tg("❌ <b>擷取失敗</b>\n伺服器硬碟中尚未產生最新畫面。這通常是因為 Nano 尚未上傳，或是處於待命狀態。", target_chat_id=sender_id)

            elif msg.startswith("/grant"):
                if sender_id != CHAT_ID:
                    send_tg("⛔ <b>存取拒絕</b> 您不是系統超級管理員。", target_chat_id=sender_id)
                    continue
                parts = msg.split()
                if len(parts) != 3:
                    send_tg("⚠️ <b>格式錯誤</b>\n請使用：<code>/grant &lt;帳號&gt; &lt;角色&gt;</code>\n範例：<code>/grant cody admin</code>", target_chat_id=sender_id)
                    continue
                
                try:
                    update_res = requests.put(f"{LOCAL_API_URL}/users/{parts[1]}/role", json={"role": parts[2]}, headers=headers, timeout=5)
                    if update_res.status_code == 200:
                        send_tg(f"✅ <b>權限變更成功</b>\n👤 帳號：<code>{parts[1]}</code>\n🔑 新角色：<code>{parts[2]}</code>", target_chat_id=sender_id)
                    else:
                        send_tg(f"❌ 更新失敗 (HTTP {update_res.status_code})\n{update_res.text}", target_chat_id=sender_id)
                except Exception as e:
                    send_tg(f"❌ 伺服器連線異常：{e}", target_chat_id=sender_id)

        # ====== 警報主動推播邏輯 ======
        res = requests.get(f"{LOCAL_API_URL}/events", headers=headers)
        evts = res.json().get("data", [])
        evts.sort(key=lambda x: x.get("id", 0))
        for e in evts:
            e_id = e.get("id", 0)
            if e_id > last_event_id:
                last_event_id = e_id
                is_gas_warn = False
                baseline = get_baseline()
                if e.get("event_type") == "sensor" and "[Gas:" in e.get("description", ""):
                    try:
                        raw = int(e.get("description", "").split("[Gas:")[1].split("/")[0])
                        calibrated = max(0, raw - baseline)
                        if calibrated > 400: is_gas_warn = True
                    except: pass
                    
                if e.get("severity") in ["critical", "high"] or is_gas_warn:
                    sev = f"🚨 <b>{e.get('severity', 'warning').upper()}</b>" if e.get("severity") in ["critical", "high"] else "⚠️ <b>WARNING</b>"
                    evt_name = "氣體濃度偏高" if is_gas_warn and e.get("severity") not in ["critical", "high"] else e.get('event_name', '未知事件')
                    
                    safe_desc = str(e.get('description', '')).replace('<', '&lt;').replace('>', '&gt;')
                    safe_evt_name = evt_name.replace('<', '&lt;').replace('>', '&gt;')
                    
                    send_tg(f"{sev}\n📍 節點: <code>{e.get('device_id', '未知')}</code>\n⚠️ 事件: {safe_evt_name}\n📝 描述: {safe_desc}")

    except Exception as e:
        print(f"Loop Error: {e}", flush=True)
    time.sleep(3)
