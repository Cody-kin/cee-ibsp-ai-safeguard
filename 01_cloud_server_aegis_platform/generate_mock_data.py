import requests, time

url = "http://localhost:80/api/v1/events"
mock_events = [
    {"device_id": "DEV-NANO-001", "event_type": "ai_vision", "event_name": "摔倒", "severity": "critical", "description": "偵測到人員倒地，信心度 85%"},
    {"device_id": "DEV-LORA-001", "event_type": "sensor", "event_name": "環境回報", "severity": "info", "description": "溫度: 28°C, 濕度: 60%"},
    {"device_id": "DEV-LORA-001", "event_type": "sensor", "event_name": "瓦斯濃度異常", "severity": "high", "description": "MQ2 讀值達 450ppm"},
    {"device_id": "DEV-NANO-001", "event_type": "ai_vision", "event_name": "火災", "severity": "critical", "description": "畫面出現異常火光，信心度 92%"},
    {"device_id": "DEV-LORA-001", "event_type": "sensor", "event_name": "環境回報", "severity": "info", "description": "溫度: 29°C, 濕度: 58%"},
    {"device_id": "DEV-NANO-001", "event_type": "ai_vision", "event_name": "摔倒", "severity": "critical", "description": "偵測到人員倒地，信心度 78%"},
    {"device_id": "DEV-LORA-001", "event_type": "sensor", "event_name": "環境回報", "severity": "info", "description": "溫度: 30°C, 濕度: 55%"},
    {"device_id": "DEV-NANO-001", "event_type": "ai_vision", "event_name": "安全", "severity": "info", "description": "無異常"}
]

print("🚀 正在注入測試數據庫...")
for evt in mock_events:
    requests.post(url, data=evt)
    time.sleep(0.5)
print("✅ 數據注入完成！")
