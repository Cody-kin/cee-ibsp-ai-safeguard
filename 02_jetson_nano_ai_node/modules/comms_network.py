import os
import requests
from dotenv import load_dotenv
load_dotenv()
import threading
import time
import cv2

class NetworkManager:
    def __init__(self):
        self.device_id = os.getenv("DEVICE_ID", "NANO-001")
        self.base_url = os.getenv("SERVER_BASE_URL", "http://127.0.0.1").rstrip("/")

        self.api_heartbeat = f"{self.base_url}/api/v1/heartbeat"
        self.api_event = f"{self.base_url}/api/v1/events"

        self.active_cameras = []
        self.camera_configs = {}
        self.stream_locks = {}
        self.system_active = True

        threading.Thread(target=self._heartbeat_and_sync, daemon=True).start()

    def update_active_cameras(self, cam_list):
        self.active_cameras = cam_list

    def _heartbeat_and_sync(self):
        while True:
            if self.active_cameras:
                try:
                    payload = {
                        "device_id": self.device_id,
                        "cameras": self.active_cameras
                    }
                    res = requests.post(self.api_heartbeat, json=payload, timeout=3)
                    if res.status_code == 200:
                        new_config = res.json()
                        if new_config and isinstance(new_config, dict) and len(new_config) > 0:
                            self.camera_configs = new_config
                except Exception:
                    pass

            time.sleep(5)

    def send_stream_async(self, cam_id, frame):
        if self.stream_locks.get(cam_id, False):
            return

        self.stream_locks[cam_id] = True
        threading.Thread(target=self._send_stream, args=(cam_id, frame), daemon=True).start()

    def _send_stream(self, cam_id, frame):
        try:
            if frame is None:
                return

            ret, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 60])
            if ret:
                stream_url = f"{self.base_url}/api/v1/stream/{self.device_id}/{cam_id}"
                headers = {'Content-Type': 'image/jpeg'}
                requests.post(stream_url, data=jpeg.tobytes(), headers=headers, timeout=2)
        except Exception:
            pass
        finally:
            self.stream_locks[cam_id] = False

    def send_event_async(self, cam_id, event_type, event_name, severity, description, frame=None):
        threading.Thread(
            target=self._send_event,
            args=(cam_id, event_type, event_name, severity, description, frame),
            daemon=True
        ).start()

    def _send_event(self, cam_id, event_type, event_name, severity, description, frame=None):
        try:
            data = {
                "device_id": self.device_id,
                "camera_id": cam_id,
                "event_type": event_type,
                "event_name": event_name,
                "severity": severity,
                "description": description
            }

            files = {}
            if frame is not None:
                ret, jpeg = cv2.imencode('.jpg', frame)
                if ret:
                    files = {'image': (f'{cam_id}_alert.jpg', jpeg.tobytes(), 'image/jpeg')}

            requests.post(self.api_event, data=data, files=files, timeout=3)

        except Exception:
            pass
