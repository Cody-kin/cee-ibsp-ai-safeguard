import torch
import os
import glob
import pathlib
import time

# 修复 Windows 训练模型在 Linux 上的 pathlib 路径问题
pathlib.WindowsPath = pathlib.PosixPath

class YoloDetector:
    def __init__(self, model_path="best.pt"):
        self.model = None
        self.model_path = os.path.abspath(model_path)

        print(f"[系統] 🧠 YOLO model path: {self.model_path}")

        if os.path.exists(self.model_path):
            st = os.stat(self.model_path)
            print(f"[系統] 🧠 YOLO model size: {st.st_size / 1024 / 1024:.2f} MB")
            print(f"[系統] 🧠 YOLO model modified: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(st.st_mtime))}")
        else:
            print(f"[錯誤] ❌ 找不到模型文件: {self.model_path}")
            return

        hub_dir = os.path.expanduser("~/.cache/torch/hub")
        yolo_dirs = sorted(
            glob.glob(os.path.join(hub_dir, "ultralytics_yolov5*")),
            key=lambda p: os.path.getmtime(p),
            reverse=True
        )

        try:
            if yolo_dirs:
                local_repo = yolo_dirs[0]
                print(f"[系統] 🛡️ 完全離線模式：使用本地 YOLOv5 repo: {local_repo}")
                self.model = torch.hub.load(
                    local_repo,
                    "custom",
                    path=self.model_path,
                    source="local",
                    force_reload=False
                )
            else:
                print("[系統] 找不到本地 YOLOv5 repo，嘗試連線 GitHub 載入...")
                self.model = torch.hub.load(
                    "ultralytics/yolov5",
                    "custom",
                    path=self.model_path,
                    force_reload=False
                )

            print(f"[系統] ✅ YOLOv5 模型載入成功: {self.model_path}")

            names = getattr(self.model, "names", None)
            print(f"[系統] 📚 Model classes: {names}")

        except Exception as e:
            print(f"[錯誤] ❌ YOLOv5 模型載入失敗: {e}")
            self.model = None

    def detect(self, frame):
        if self.model is None:
            return []

        results = self.model(frame)
        detections = []

        df = results.pandas().xyxy[0]
        for _, row in df.iterrows():
            detections.append({
                "bbox": [int(row["xmin"]), int(row["ymin"]), int(row["xmax"]), int(row["ymax"])],
                "class": row["name"],
                "conf": float(row["confidence"])
            })

        return detections
