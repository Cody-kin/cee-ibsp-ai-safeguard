import os

file_path = "backend/app/routers/devices.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 引入 Pydantic 模型
if "from pydantic import BaseModel" not in content:
    content = content.replace("from fastapi import APIRouter", "from pydantic import BaseModel\nfrom fastapi import APIRouter")

# 移除舊的 system_command 路由
import re
content = re.sub(r'@router\.post\("/(?:devices/)?\{device_id\}/system_command"\)[\s\S]*?(?=@router|$)', '', content)

# 加上最嚴謹的新版路由
new_route = """
class SysCmd(BaseModel):
    command: str

@router.post("/devices/{device_id}/system_command")
async def send_system_command(device_id: str, cmd_data: SysCmd):
    if cmd_data.command in ["START", "STOP"]:
        cmd_str = f"SYS|{cmd_data.command}\\n"
        with open(f"{LORA_CMD_DIR}/pending.txt", "w") as f_out:
            f_out.write(cmd_str)
        return {"status": "success", "message": "Command queued"}
    return {"status": "error", "message": "Invalid command"}
"""
content += new_route

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ 後端 API 已經升級為嚴謹模型！")
