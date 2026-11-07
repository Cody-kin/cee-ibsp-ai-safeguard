import threading
from flask import Flask, Response, jsonify
import cv2
import logging

# 屏蔽 Flask 預設的洗版日誌
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

app = Flask(__name__)

# 存放獨立的影像流與狀態
cam_frames = {"cam1": None, "cam2": None}
cam_status = {"cam1": False, "cam2": False}
lock = threading.Lock()

def update_frame(cam_name, frame):
    with lock:
        if frame is not None:
            cam_frames[cam_name] = frame.copy()
            cam_status[cam_name] = True
        else:
            cam_status[cam_name] = False

def set_offline(cam_name):
    with lock:
        cam_status[cam_name] = False

@app.route('/')
def index():
    # 完美嵌入你的精美 HTML
    return """<!DOCTYPE html><html><head><title>AI-SafeGuard 双摄监控台</title><style>* { box-sizing: border-box; margin: 0; padding: 0; }body {background: #0a0a0a; color: #00ffcc;font-family: 'Courier New', monospace;padding: 15px;}.header {text-align: center; padding: 10px 0 15px;border-bottom: 1px solid #1a3a30;margin-bottom: 15px;}.header h2 { font-size: 1.3em; margin-bottom: 4px; }.header .sub { font-size: 0.8em; color: #666; }.cam-grid {display: flex; flex-wrap: wrap;justify-content: center; gap: 12px;}.cam-card {border: 2px solid #1a3a30; border-radius: 8px;overflow: hidden; background: #111;width: 640px; transition: border-color 0.3s;}.cam-card.online { border-color: #00ffcc; }.cam-card.offline { border-color: #ff3333; opacity: 0.5; }.cam-card .top-bar {display: flex; justify-content: space-between;align-items: center; padding: 4px 10px;background: #0d1f1a; font-size: 0.85em;}.cam-card .top-bar .dot {width: 8px; height: 8px; border-radius: 50%;display: inline-block; margin-right: 6px;}.dot.green { background: #00ff88; box-shadow: 0 0 6px #00ff88; }.dot.red { background: #ff3333; box-shadow: 0 0 6px #ff3333; }.cam-card img { width: 100%; display: block; min-height: 360px; background: #000; }.footer {text-align: center; margin-top: 15px;font-size: 0.8em; color: #444;}</style></head><body><div class="header"><h2>⚡ AI-SafeGuard 边缘 AI 监控中心</h2><div class="sub">YOLOv5 + 语音辨识 | 双轨通讯: API + LoRa | 可选检测目标</div></div><div class="cam-grid" id="camGrid"><div class="cam-card offline" id="card-cam1"><div class="top-bar"><span><span class="dot red" id="dot-cam1"></span>CAM-1</span><span id="status-cam1">离线</span></div><img src="/feed/cam1" id="img-cam1"></div><div class="cam-card offline" id="card-cam2"><div class="top-bar"><span><span class="dot red" id="dot-cam2"></span>CAM-2</span><span id="status-cam2">离线</span></div><img src="/feed/cam2" id="img-cam2"></div></div><div class="footer">🟢 Jetson Nano 本地监控 | 检测目标设定在 modules/config.py</div><script>setInterval(() => {fetch('/api/cam_status').then(r => r.json()).then(data => {['cam1', 'cam2'].forEach(c => {let card = document.getElementById('card-' + c);let dot = document.getElementById('dot-' + c);let st = document.getElementById('status-' + c);if (data[c]) {card.className = 'cam-card online';dot.className = 'dot green';st.textContent = '在线';} else {card.className = 'cam-card offline';dot.className = 'dot red';st.textContent = '离线';}});}).catch(() => {});}, 3000);</script></body></html>"""

def generate(cam_name):
    while True:
        with lock:
            frame = cam_frames.get(cam_name)
        
        if frame is None:
            import time
            time.sleep(0.1)
            continue
            
        ret, jpeg = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 60])
        if ret:
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + jpeg.tobytes() + b'\r\n')
        
        import time
        time.sleep(0.05) # 控制網頁幀率，保護 Nano CPU

@app.route('/feed/cam1')
def video_feed_cam1():
    return Response(generate('cam1'), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/feed/cam2')
def video_feed_cam2():
    return Response(generate('cam2'), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/api/cam_status')
def get_status():
    with lock:
        return jsonify(cam_status)

def start_server():
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True, use_reloader=False)
