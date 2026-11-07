#!/usr/bin/env python3
import time
import threading
import cv2
import ctypes
import numpy as np
import socket
import os
import subprocess
from datetime import datetime
from modules.comms_network import NetworkManager
from modules.detector import YoloDetector
from modules.comms_lora import LoRaManager
from modules.audio_detector import AudioDetector
from modules import local_stream

os.environ['OPENCV_LOG_LEVEL'] = 'SILENT'
os.environ['OPENCV_VIDEOIO_DEBUG'] = '0'

ERROR_HANDLER_FUNC = ctypes.CFUNCTYPE(None, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p)

def py_error_handler(filename, line, function, err, fmt):
    pass

c_error_handler = ERROR_HANDLER_FUNC(py_error_handler)
try:
    asound = ctypes.cdll.LoadLibrary('libasound.so.2')
    asound.snd_lib_error_set_handler(c_error_handler)
except Exception:
    pass

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

# -----------------------------------------------------
# YOLO label mapping
# New best.pt:
# fall, fire, normal, smoke, Safety_vest, head, helmet, phone, smoking
# Website controls:
# fire, smoke, fall, hardhat, vest, smoking, phone
# -----------------------------------------------------
DIRECT_DANGER_MAP = {
    "fire": "fire",
    "smoke": "smoke",
    "fall": "fall",
    "fallen": "fall",
    "phone": "phone",
    "smoking": "smoking",
}

SAFE_LABELS = set(["normal", "helmet", "safety_vest", "safety vest"])

# -----------------------------------------------------
# Camera quality profile
# cam0 sometimes starts dark / blurry on UVC cameras.
# This applies auto exposure / white balance and allows per-camera resolution.
# -----------------------------------------------------
CAMERA_PROFILES = {
    0: {"width": 640, "height": 480, "fps": 10},
    1: {"width": 320, "height": 240, "fps": 10},
}

def apply_camera_tuning(src):
    if not isinstance(src, int):
        return

    dev = f"/dev/video{src}"

    # v4l2 controls differ by camera model.
    # Unsupported controls are ignored safely.
    controls = [
        ("exposure_auto", 3),
        ("auto_exposure", 3),
        ("exposure_auto_priority", 1),
        ("gain_automatic", 1),
        ("white_balance_temperature_auto", 1),
        ("focus_auto", 1),
        ("backlight_compensation", 1),
    ]

    for name, value in controls:
        try:
            subprocess.run(
                ["v4l2-ctl", "-d", dev, "--set-ctrl", f"{name}={value}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=1
            )
        except Exception:
            pass


def norm_label(label):
    return str(label or "").strip().lower().replace("-", "_")

def send_lora_line(lora, line):
    if not lora or not getattr(lora, "ser", None):
        return False

    try:
        if hasattr(lora, "send_line"):
            return lora.send_line(line)

        lora.ser.write((line.strip() + "\n").encode("utf-8"))
        lora.ser.flush()
        return True
    except Exception:
        return False

class ThreadedCamera:
    def __init__(self, src):
        self.src = src
        self.cap = None
        self.ret = False
        self.frame = None
        self.running = False
        self.frame_count = 0
        self.last_change_time = time.time()
        self.last_small = None

        self._open_camera()

        if self.ret and self.frame is not None:
            self.running = True
            threading.Thread(target=self.update, daemon=True).start()

    def _open_camera(self):
        # Use V4L2 directly. On old OpenCV, 200 + index also maps to V4L2.
        apply_camera_tuning(self.src)

        apply_camera_tuning(self.src)

        magic_src = 200 + self.src if isinstance(self.src, int) else self.src

        self.cap = cv2.VideoCapture(magic_src)

        if not self.cap.isOpened():
            self.ret = False
            return

        try:
            profile = CAMERA_PROFILES.get(self.src, {"width": 320, "height": 240, "fps": 10})
            width = int(os.getenv(f"CAM{self.src}_WIDTH", str(profile.get("width", 320))))
            height = int(os.getenv(f"CAM{self.src}_HEIGHT", str(profile.get("height", 240))))
            fps = int(os.getenv(f"CAM{self.src}_FPS", str(profile.get("fps", 10))))

            self.cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc('M', 'J', 'P', 'G'))
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
            self.cap.set(cv2.CAP_PROP_FPS, fps)

            # OpenCV camera controls. Unsupported ones are ignored by driver.
            try:
                self.cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.75)
                self.cap.set(cv2.CAP_PROP_AUTO_WB, 1)
                self.cap.set(cv2.CAP_PROP_GAIN, 0)
            except Exception:
                pass

            log(f"📷 cam_{self.src} requested {width}x{height}@{fps}")

            # CAP_PROP_BUFFERSIZE removed: many V4L2 cameras do not support property #38.

            # Warm up and flush stale frames.
            ok = False
            frame = None
            for _ in range(8):
                self.cap.grab()
                ok, frame = self.cap.read()
                time.sleep(0.03)

            self.ret = bool(ok and frame is not None)
            self.frame = frame if self.ret else None

            if self.ret:
                self.last_small = cv2.resize(self.frame, (32, 24))
                self.last_change_time = time.time()
                log(f"✅ Camera cam_{self.src} opened with anti-freeze mode")

        except Exception as e:
            log(f"❌ Camera cam_{self.src} open failed: {e}")
            self.ret = False
            try:
                self.cap.release()
            except Exception:
                pass

    def _frame_changed(self, frame):
        try:
            small = cv2.resize(frame, (32, 24))

            if self.last_small is None:
                self.last_small = small
                self.last_change_time = time.time()
                return True

            diff = cv2.absdiff(small, self.last_small)
            score = float(diff.mean())

            # Normal small camera noise is often enough. If score is almost 0 for long time,
            # the camera is likely stuck on the same frame.
            if score > 0.8:
                self.last_small = small
                self.last_change_time = time.time()
                return True

            return False

        except Exception:
            return True

    def update(self):
        fail_count = 0
        stale_warned = False

        while self.running:
            try:
                if not self.cap or not self.cap.isOpened():
                    break

                # Flush old USB/V4L2 frames so cam0 does not stay on the first cached image.
                for _ in range(2):
                    self.cap.grab()

                ret, frame = self.cap.read()

                if ret and frame is not None:
                    self.ret = True
                    self.frame = frame
                    self.frame_count += 1
                    fail_count = 0

                    changed = self._frame_changed(frame)

                    # If the image is truly unchanged for too long, force reconnect.
                    if not changed and (time.time() - self.last_change_time > 6.0):
                        if not stale_warned:
                            log(f"⚠️ cam_{self.src} frame seems frozen, reconnecting camera...")
                            stale_warned = True
                        break

                    if changed:
                        stale_warned = False

                else:
                    fail_count += 1
                    if fail_count > 10:
                        log(f"⚠️ cam_{self.src} read failed too many times")
                        break

            except Exception as e:
                log(f"⚠️ cam_{self.src} update exception: {e}")
                break

            time.sleep(0.02)

        self.ret = False
        self.running = False

        try:
            if self.cap and self.cap.isOpened():
                self.cap.release()
        except Exception:
            pass

    def read(self):
        if self.ret and self.frame is not None:
            return True, self.frame.copy()
        return False, None

    def release(self):
        self.running = False
        try:
            if self.cap and self.cap.isOpened():
                self.cap.release()
        except Exception:
            pass


class MultiCameraManager:
    def __init__(self):
        self.caps = {}

    def scan_cameras(self):
        for i in list(self.caps.keys()):
            if not self.caps[i].ret:
                self.caps[i].release()
                del self.caps[i]
                local_stream.set_offline(f"cam{i+1}")
                log(f"⚠️ 鏡頭已離線: cam_{i}")

        if len(self.caps) < 2:
            for i in range(4):
                if len(self.caps) >= 2:
                    break

                if not os.path.exists(f"/dev/video{i}"):
                    continue

                if i not in self.caps:
                    t_cam = ThreadedCamera(i)
                    if t_cam.running:
                        self.caps[i] = t_cam
                        log(f"📸 偵測到鏡頭上線: cam_{i}")
                    else:
                        t_cam.release()

        return [f"cam_{i}" for i in self.caps.keys()]

def build_allowed_tasks(network, api_cam_id, default_thresholds):
    cam_config = network.camera_configs.get(api_cam_id)
    allowed_tasks = default_thresholds.copy()

    if isinstance(cam_config, list):
        allowed_tasks = {
            str(task).lower().strip(): default_thresholds.get(str(task).lower().strip(), 0.35)
            for task in cam_config
        }
    elif isinstance(cam_config, dict):
        allowed_tasks = {key: 0.0 for key in default_thresholds}
        for k, v in cam_config.items():
            key = str(k).lower().strip()
            try:
                allowed_tasks[key] = float(v)
            except Exception:
                pass

    return allowed_tasks

def analyze_detections(raw_detections, allowed_tasks):
    """
    Returns alert detections.

    Direct danger:
      fire/smoke/fall/smoking/phone

    PPE logic:
      helmet and Safety_vest are safe.
      head + no helmet => no_helmet alert, controlled by hardhat slider.
      worker/head/helmet seen + no Safety_vest => no_vest alert, controlled by vest slider.

    This is a heuristic because current model has Safety_vest but no explicit no_vest class.
    """
    alerts = []

    head_dets = []
    helmet_dets = []
    vest_dets = []
    worker_seen_dets = []

    for det in raw_detections:
        raw = norm_label(det.get("class"))
        conf = float(det.get("conf", 0))

        # Direct dangerous classes
        if raw in DIRECT_DANGER_MAP:
            key = DIRECT_DANGER_MAP[raw]
            target = float(allowed_tasks.get(key, 0.0))
            if target > 0 and conf >= target:
                d = det.copy()
                d["alert_key"] = key
                d["alert_name"] = key
                d["severity"] = "critical"
                alerts.append(d)

        # PPE safe / presence classes
        if raw == "head":
            head_dets.append(det)
            worker_seen_dets.append(det)
        elif raw == "helmet":
            helmet_dets.append(det)
            worker_seen_dets.append(det)
        elif raw in ["safety_vest", "safety vest", "vest"]:
            vest_dets.append(det)
            worker_seen_dets.append(det)

    # Missing helmet: head visible but helmet not detected
    hardhat_threshold = float(allowed_tasks.get("hardhat", 0.0))
    if hardhat_threshold > 0 and head_dets and not helmet_dets:
        best_head = max(head_dets, key=lambda d: float(d.get("conf", 0)))
        conf = float(best_head.get("conf", 0))
        if conf >= hardhat_threshold:
            d = best_head.copy()
            d["alert_key"] = "hardhat"
            d["alert_name"] = "no_helmet"
            d["severity"] = "critical"
            alerts.append(d)

    # Missing vest: worker/person related object seen but no Safety_vest detected
    vest_threshold = float(allowed_tasks.get("vest", 0.0))
    if vest_threshold > 0 and worker_seen_dets and not vest_dets:
        best_worker = max(worker_seen_dets, key=lambda d: float(d.get("conf", 0)))
        conf = float(best_worker.get("conf", 0))
        if conf >= vest_threshold:
            d = best_worker.copy()
            d["alert_key"] = "vest"
            d["alert_name"] = "no_vest"
            d["severity"] = "critical"
            alerts.append(d)

    return alerts

def main():
    local_ip = get_local_ip()
    log("=== 🚀 AI-SafeGuard 終極順暢版 (遠端遙控 + 本機日誌) ===")

    threading.Thread(target=local_stream.start_server, daemon=True).start()
    log(f"📺 本地雙鏡頭監視器: http://{local_ip}:5000")

    network = NetworkManager()
    network.system_active = True
    cam_manager = MultiCameraManager()

    log("🧠 AI 模型加載與預熱中...")
    model_path = os.path.abspath("best.pt")
    log(f"🧠 Loading YOLO model from: {model_path}")
    model = YoloDetector(model_path=model_path)

    if model.model is None:
        log("❌ YOLO 模型未成功載入，程式停止。")
        return

    try:
        model.model.conf = 0.25
        model.model.iou = 0.45
        model.model.max_det = 8
    except Exception:
        pass

    try:
        model_names = getattr(model.model, "names", {})
        log(f"📚 Model classes: {model_names}")
    except Exception:
        pass

    model.detect(np.zeros((240, 320, 3), dtype=np.uint8))
    log("✅ AI 預熱完畢，系統正式防護中！")

    lora = LoRaManager(network_manager=network)
    audio = AudioDetector(network, lora)

    if lora.ser:
        log(f"📡 LoRa 模組連線成功: {lora.ser.port}")
        send_lora_line(lora, "sys_log|boot|info|nano_main_started")

    last_scan_time = 0
    cam_index_turn = 0
    last_stream_time = {}
    last_alert_time = {}

    DEFAULT_THRESHOLDS = {
        "fire": 0.40,
        "smoke": 0.35,
        "fall": 0.45,
        "hardhat": 0.35,
        "vest": 0.35,
        "smoking": 0.40,
        "phone": 0.40,
    }

    log(f"📚 Active UI-controlled labels: {DEFAULT_THRESHOLDS}")

    try:
        while True:
            curr_t = time.time()

            if not getattr(network, "system_active", True):
                if len(cam_manager.caps) > 0:
                    for idx in list(cam_manager.caps.keys()):
                        cam_manager.caps[idx].release()
                        del cam_manager.caps[idx]
                        local_stream.set_offline(f"cam{idx+1}")
                    log("💤 鏡頭已釋放，系統安靜待命...")
                time.sleep(1)
                continue

            if curr_t - last_scan_time > 3:
                active_cam_list = cam_manager.scan_cameras()
                network.update_active_cameras(active_cam_list)
                last_scan_time = curr_t

            alive_indices = list(cam_manager.caps.keys())
            if not alive_indices:
                time.sleep(0.5)
                continue

            current_idx = alive_indices[cam_index_turn % len(alive_indices)]
            api_cam_id = f"cam_{current_idx}"
            local_cam_id = f"cam{current_idx + 1}"
            cam_index_turn += 1

            cap = cam_manager.caps[current_idx]
            ret, frame = cap.read()
            if not ret or frame is None:
                time.sleep(0.05)
                continue

            if api_cam_id not in last_stream_time:
                last_stream_time[api_cam_id] = 0

            if api_cam_id not in last_alert_time:
                last_alert_time[api_cam_id] = 0

            allowed_tasks = build_allowed_tasks(network, api_cam_id, DEFAULT_THRESHOLDS)

            raw_detections = model.detect(frame)
            display_frame = frame.copy()

            cv2.putText(display_frame, f"[{api_cam_id.upper()}]", (10, 25),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)

            # Draw safe detections in green / blue
            for det in raw_detections:
                raw = norm_label(det.get("class"))
                conf = float(det.get("conf", 0))
                x1, y1, x2, y2 = map(int, det["bbox"])

                if raw in ["helmet", "safety_vest", "safety vest", "normal"]:
                    cv2.rectangle(display_frame, (x1, y1), (x2, y2), (0, 180, 0), 2)
                    cv2.putText(display_frame, f"OK:{raw} {conf:.2f}", (x1, y1 - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 220, 0), 1)
                elif raw == "head":
                    cv2.rectangle(display_frame, (x1, y1), (x2, y2), (255, 160, 0), 1)
                    cv2.putText(display_frame, f"head {conf:.2f}", (x1, y1 - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 160, 0), 1)

            alert_detections = analyze_detections(raw_detections, allowed_tasks)
            has_danger = len(alert_detections) > 0

            if has_danger:
                alert_detections.sort(key=lambda x: float(x.get("conf", 0)), reverse=True)
                danger_label = alert_detections[0].get("alert_name", "ai_alert")
                max_conf = float(alert_detections[0].get("conf", 0))

                for det in alert_detections:
                    x1, y1, x2, y2 = map(int, det["bbox"])
                    label = det.get("alert_name", det.get("class", "alert"))
                    conf = float(det.get("conf", 0))

                    cv2.rectangle(display_frame, (x1, y1), (x2, y2), (0, 0, 255), 2)
                    cv2.putText(display_frame, f"{label} {conf:.2f}", (x1, y1 - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)

                if curr_t - last_alert_time[api_cam_id] >= 3.0:
                    description = f"AI detected {danger_label} on {api_cam_id} (Conf: {max_conf:.2f})"

                    # Cloud API event with image. This is the old online reporting feature.
                    network.send_event_async(
                        cam_id=api_cam_id,
                        event_type="ai_vision",
                        event_name=f"{danger_label.capitalize()} Detected",
                        severity="critical",
                        description=description,
                        frame=display_frame
                    )

                    # LoRaWAN backup event.
                    send_lora_line(
                        lora,
                        f"ai_vision|{danger_label} ({api_cam_id})|critical|AI alert on {api_cam_id}"
                    )

                    log(f"🚨 [警報上傳] {api_cam_id} 偵測到 {danger_label}！(信心度: {max_conf:.2f})")
                    last_alert_time[api_cam_id] = curr_t

            if curr_t - last_stream_time[api_cam_id] >= 0.5:
                network.send_stream_async(api_cam_id, display_frame)
                last_stream_time[api_cam_id] = curr_t
                log(f"☁️ [常規直播] {api_cam_id} 運作中...")

            local_stream.update_frame(local_cam_id, display_frame)

    except KeyboardInterrupt:
        log("系統手動停止")

    except Exception as e:
        log(f"❌ 系統崩潰: {e}")
        try:
            crash_msg = str(e).replace("\n", " ")
            send_lora_line(lora, f"sys_log|System Crash|critical|Main loop crashed: {crash_msg}")
        except Exception:
            pass

if __name__ == "__main__":
    main()
