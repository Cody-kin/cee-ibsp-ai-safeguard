import os
from dotenv import load_dotenv

load_dotenv()

SERVER_UPLOAD_URL = os.getenv("SERVER_UPLOAD_URL", "http://127.0.0.1/api/v1/events")
DEVICE_ID = os.getenv("DEVICE_ID", "DEV-NANO-001")

LORA_PORT = os.getenv("LORA_PORT", "/dev/ttyUSB0")
LORA_BAUDRATE = int(os.getenv("LORA_BAUDRATE", 115200))
STREAM_PORT = int(os.getenv("STREAM_PORT", 5000))

# ============================================================
#  检测目标开关 (True=启用, False=关闭)
#  在这里选择你要检测什么，改完重启 main.py 即可生效
# ============================================================
DETECT_FALL  = True    # 人员跌倒
DETECT_FIRE  = True    # 火焰
DETECT_SMOKE = True    # 烟雾

# 各目标的置信度阈值 (越高越严格，越不容易误报)
CONF_FALL  = 0.40
CONF_FIRE  = 0.35
CONF_SMOKE = 0.30

# 正常人框显示
SHOW_PERSON = True     # 是否画蓝色「正常人」框
CONF_PERSON = 0.30
