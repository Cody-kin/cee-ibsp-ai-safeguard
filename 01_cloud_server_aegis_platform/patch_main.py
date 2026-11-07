import sys

file_path = "backend/app/main.py"
try:
    with open(file_path, "r") as f:
        content = f.read()
except Exception as e:
    print(f"❌ 找不到 {file_path}")
    sys.exit(1)

if "devices.router" not in content:
    with open(file_path, "a") as f:
        f.write("\n\n# --- 動態分流路由 (動態修復) ---")
        f.write("\ntry:\n    from app.routers import devices\nexcept ImportError:\n    from routers import devices\n")
        f.write("app.include_router(devices.router)\n")
    print("✅ 手術成功：已將 devices 動態路由強制寫入 main.py 的最底部！")
else:
    print("✅ 路由已經存在，無需重複寫入！")
