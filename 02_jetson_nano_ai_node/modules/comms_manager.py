import serial
import requests
import threading
import queue
import cv2
import time

SERVER_URL = "http://127.0.0.1/api/v1/events"
DEVICE_ID = "DEV-NANO-001"

class CommsManager:
    def __init__(self):
        self.lora = None
        self.init_lora()
        # 佇列：只保留最新的一張，舊的沒傳完就丟掉，保證不卡死
        self.q = queue.Queue(maxsize=1)
        threading.Thread(target=self._worker, daemon=True).start()

    def init_lora(self):
        for port in ['/dev/ttyUSB0', '/dev/ttyACM0']:
            try:
                self.lora = serial.Serial(port, 115200, timeout=1)
                print(f"[系統] LoRa OK ({port})")
                return
            except: continue
        print("[警告] LoRa 離線")

    def _worker(self):
        """背景工人：專門處理不穩定的 502 網路"""
        while True:
            try:
                frame, is_alert, alert_name = self.q.get()
                success, img = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
                if not success: continue

                files = {'image': ('f.jpg', img.tobytes(), 'image/jpeg')}
                data = {
                    'device_id': DEVICE_ID,
                    'event_type': 'ai_vision',
                    'event_name': alert_name,
                    'severity': 'critical' if is_alert else 'info',
                    'description': 'Nano Live'
                }
                
                # 嚴格限制 Timeout 為 2 秒
                res = requests.post(SERVER_URL, data=data, files=files, timeout=2)
                if res.status_code != 201:
                    print(f" [伺服器] 狀態碼: {res.status_code} (可能正在 502)")
                
                self.q.task_done()
            except Exception:
                time.sleep(1) # 連線失敗休息一秒再試

    def send_frame_to_cloud(self, frame, is_alert=False, alert_name="heartbeat"):
        try:
            if self.q.full(): self.q.get_nowait()
            self.q.put_nowait((frame, is_alert, alert_name))
        except: pass

    def send_to_lora_serial(self, event_en, severity, desc):
        if self.lora and self.lora.is_open:
            try:
                self.lora.write(f"AI_ALERT|{event_en}|{severity}|{desc}\n".encode())
            except: pass

    def trigger_event(self, en, zh, sev, desc, frame):
        self.send_frame_to_cloud(frame, True, zh)
        self.send_to_lora_serial(en, sev, desc)
