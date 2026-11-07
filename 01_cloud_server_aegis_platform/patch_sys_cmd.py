import os

file_path = "backend/app/routers/devices.py"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 如果還沒有 system_command 接口，就把它加到檔案最後面
if "/system_command" not in content:
    new_endpoint = """
@router.post("/{device_id}/system_command")
async def send_system_command(device_id: str, request: Request):
    try:
        data = await request.json()
        command = data.get("command")
        if command in ["START", "STOP"]:
            cmd_str = f"SYS|{command}\\n"
            with open(f"{LORA_CMD_DIR}/pending.txt", "w") as f_out:
                f_out.write(cmd_str)
            return {"status": "success", "message": f"Command {cmd_str} queued"}
        return {"status": "error", "message": "Invalid command"}
    except:
        return {"status": "error"}
"""
    with open(file_path, "a", encoding="utf-8") as f:
        f.write(new_endpoint)
    print("✅ 後端 SYS 指令接口已成功添加！")
else:
    print("⚡ 接口已存在，跳過添加。")
