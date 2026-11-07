#!/usr/bin/env python3
import os, sys, ctypes, time, threading, cv2
from collections import deque

# 徹底封鎖 ALSA 報錯
ERROR_HANDLER_FUNC = ctypes.CFUNCTYPE(None, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p)
def py_error_handler(filename, line, function, err, fmt): pass
c_error_handler = ERROR_HANDLER_FUNC(py_error_handler)
try:
    asound = ctypes.cdll.LoadLibrary('libasound.so.2')
    asound.snd_lib_error_set_handler(c_error_handler)
except: pass

from modules.camera_manager import CameraManager
from modules.detector import YoloDetector
from modules.alert_logic import AlertLogic
from modules.comms_manager import CommsManager  
from modules.audio_detector import AudioDetector
from modules import local_stream

class VisionSystem:
    def __init__(self):
        self.camera = CameraManager()
        self.model = YoloDetector(model_path="best.pt")
        self.comms = CommsManager()
        self.audio = AudioDetector(self.comms)
        self.logic = AlertLogic()
        
        self.current_frame = None
        self.running = True
        
        # 增加校驗幀數到 6 幀
        self.detection_history = deque(maxlen=6)
        
        threading.Thread(target=local_stream.start_server, daemon=True).start()
        threading.Thread(target=self._camera_loader, daemon=True).start()

    def _camera_loader(self):
        while self.running:
            frame, _ = self.camera.read_frame()
            if frame is not None: self.current_frame = frame
            time.sleep(0.01)

    def run(self):
        print("[系統] 🚀 啟動「終極冷靜」監控模式...")
        last_stream_time = 0
        last_alert_time = 0
        last_normal_print = 0
        
        while self.running:
            if self.current_frame is None:
                time.sleep(0.05)
                continue

            img = self.current_frame.copy()
            detections = self.model.detect(img) 
            
            display_img = img.copy()
            cv2.putText(display_img, f"CAM: {self.camera.cam_type}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
            
            frame_results = []
            best_label = "NORMAL"

            for det in detections:
                x1, y1, x2, y2 = det['bbox']
                name, conf = det['class'].lower(), det['conf']
                w, h = x2 - x1, y2 - y1

                # 🛡️ 核心防護：物理特徵檢查 (如果高度 > 寬度的 1.2 倍，絕對不可能是跌倒)
                is_vertical = h > (w * 1.2)
                
                # 門檻提高到 0.85
                if name in ['fall', 'fallen']:
                    if conf >= 0.85 and not is_vertical:
                        frame_results.append('FALL')
                        color, label = (0, 0, 255), "FALL"
                    else:
                        # 如果 AI 覺得是跌倒但人是立著的，強行修正為 NORMAL
                        color, label = (0, 255, 0), "STAND_MISJUDGE"
                elif name in ['fire', 'smoke'] and conf >= 0.60:
                    frame_results.append('DANGER')
                    color, label = (0, 0, 255), "DANGER"
                elif name in ['normal', 'person', 'standing', 'walking']:
                    color, label = (0, 255, 0), "NORMAL"
                else:
                    color, label = (255, 255, 0), "OBJ"

                best_label = label
                cv2.rectangle(display_img, (x1, y1), (x2, y2), color, 2)
                cv2.putText(display_img, f"{label} {conf:.2f}", (x1, y1-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

            self.detection_history.append(frame_results)
            
            # 多幀投票：6 幀中必須有 4 幀確診
            all_history = [item for sublist in self.detection_history for item in sublist]
            is_real_fall = all_history.count('FALL') >= 4
            
            local_stream.output_frame = display_img
            curr_t = time.time()

            if is_real_fall:
                print(f"📸 【影像確診】發生真實跌倒！")
            elif curr_t - last_normal_print >= 5:
                print(f"[狀態] ✅ 目前環境安全 (當前偵測: {best_label})")
                last_normal_print = curr_t

            if curr_t - last_stream_time >= 1.0:
                self.comms.send_frame_to_cloud(display_img, False)
                last_stream_time = curr_t

            if is_real_fall and (curr_t - last_alert_time >= 15):
                self.comms.trigger_event("FALL", "跌倒確診", "critical", "Logic_Filter_Pass", display_img)
                last_alert_time = curr_t

if __name__ == "__main__":
    sys = VisionSystem()
    try:
        sys.run()
    except KeyboardInterrupt:
        sys.running = False
