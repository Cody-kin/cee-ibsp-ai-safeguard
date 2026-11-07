import cv2
import time

class SingleCamera:
    def __init__(self, cam_id, source, cam_type="USB"):
        self.cam_id = cam_id
        self.source = source
        self.cam_type = cam_type
        self.cap = None
        self.alive = False
        self._fail_count = 0
        self._open()

    def _open(self):
        try:
            if isinstance(self.source, str):
                self.cap = cv2.VideoCapture(self.source, cv2.CAP_GSTREAMER)
            else:
                self.cap = cv2.VideoCapture(self.source)
                if self.cap.isOpened():
                    self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                    self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

            if self.cap and self.cap.isOpened():
                # 丢弃前几帧让管道稳定
                for _ in range(5):
                    self.cap.read()
                    time.sleep(0.05)
                ret, test = self.cap.read()
                if ret and test is not None:
                    self.alive = True
                    self._fail_count = 0
                    print(f"[摄像头] {self.cam_id} 就绪 ({self.cam_type}, {test.shape[1]}x{test.shape[0]})")
                    return
            self.alive = False
        except Exception as e:
            print(f"[摄像头] {self.cam_id} 异常: {e}")
            self.alive = False

    def read(self):
        if not self.alive or self.cap is None or not self.cap.isOpened():
            return None
        ret, frame = self.cap.read()
        if not ret or frame is None:
            self._fail_count += 1
            if self._fail_count >= 5:
                self.alive = False
                print(f"[摄像头] {self.cam_id} 连续失败，标记离线")
            return None
        self._fail_count = 0
        return frame

    def reconnect(self):
        if self.cap:
            try: self.cap.release()
            except: pass
        time.sleep(1)
        self._open()
        return self.alive

    def release(self):
        if self.cap:
            try: self.cap.release()
            except: pass


class DualCameraManager:
    def __init__(self):
        self.cameras = {}
        self._retry_interval = 15
        self._last_retry = {}
        self._init_cameras()

    def _init_cameras(self):
        csi_ok = False

        # --- 尝试 CSI ---
        csi_pipeline = (
            "nvarguscamerasrc ! video/x-raw(memory:NVMM), width=640, height=480, "
            "format=(string)NV12, framerate=(fraction)30/1 ! nvvidconv ! "
            "video/x-raw, format=(string)BGRx ! videoconvert ! "
            "video/x-raw, format=(string)BGR ! appsink drop=true"
        )
        try:
            cam = SingleCamera("CAM-1", csi_pipeline, "CSI")
            if cam.alive:
                self.cameras["CAM-1"] = cam
                csi_ok = True
        except:
            pass

        # --- USB：不扫描，直接按顺序开，开了就不关 ---
        if csi_ok:
            # CSI 占了 CAM-1，USB 给 CAM-2
            print("[摄像头] CSI 已就绪，尝试 USB 作为 CAM-2...")
            time.sleep(1)
            cam = SingleCamera("CAM-2", 0, "USB")
            if cam.alive:
                self.cameras["CAM-2"] = cam
            elif not cam.alive:
                cam = SingleCamera("CAM-2", 1, "USB")
                if cam.alive:
                    self.cameras["CAM-2"] = cam
        else:
            # 无 CSI，两个都用 USB
            print("[摄像头] 无 CSI，尝试双 USB...")
            cam1 = SingleCamera("CAM-1", 0, "USB")
            if cam1.alive:
                self.cameras["CAM-1"] = cam1
                # ★ 关键：等 2 秒让第一个摄像头的 USB 管道完全稳定
                print("[摄像头] CAM-1 已占用 USB，等待 2 秒再开 CAM-2...")
                time.sleep(2)
                cam2 = SingleCamera("CAM-2", 1, "USB")
                if cam2.alive:
                    self.cameras["CAM-2"] = cam2
                else:
                    print("[摄像头] CAM-2 开启失败，尝试降低 CAM-2 分辨率...")
                    cam2 = SingleCamera("CAM-2", 1, "USB-LOW")
                    if cam2.cap and cam2.cap.isOpened():
                        cam2.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)
                        cam2.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
                        time.sleep(1)
                        ret, _ = cam2.cap.read()
                        if ret:
                            cam2.alive = True
                            cam2.cam_type = "USB-320p"
                            self.cameras["CAM-2"] = cam2
                            print(f"[摄像头] CAM-2 以 320x240 低分辨率就绪 ✅")
            else:
                # video0 失败，试 video1
                cam1 = SingleCamera("CAM-1", 1, "USB")
                if cam1.alive:
                    self.cameras["CAM-1"] = cam1

        if not self.cameras:
            print("[摄像头] ❌ 未找到任何摄像头")
        else:
            total = len(self.cameras)
            names = ", ".join(f"{cid}({c.cam_type})" for cid, c in self.cameras.items())
            print(f"[摄像头] === 共 {total} 个就绪: {names} ===")

    def read_all(self):
        results = []
        now = time.time()
        for cam_id in ["CAM-1", "CAM-2"]:
            cam = self.cameras.get(cam_id)
            if cam is None or not cam.alive:
                last = self._last_retry.get(cam_id, 0)
                if now - last >= self._retry_interval:
                    self._last_retry[cam_id] = now
                    if cam:
                        ok = cam.reconnect()
                        if ok:
                            print(f"[摄像头] {cam_id} 重连成功 ✅")
                continue
            frame = cam.read()
            if frame is not None:
                results.append((cam_id, frame))
            # 两个 USB 摄像头之间加延迟减少总线冲突
            if len(self.cameras) > 1:
                time.sleep(0.02)
        return results

    def get_active_ids(self):
        return [cid for cid, c in self.cameras.items() if c.alive]
