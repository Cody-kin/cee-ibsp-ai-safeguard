from main import app
from fastapi.routing import APIRoute

print("\n========================================================")
print("🚀 目前伺服器 (FastAPI) 實際運作中的 API 接收規則：")
print("========================================================")

count = 0
for route in app.routes:
    if isinstance(route, APIRoute):
        methods = ",".join(route.methods)
        print(f"[{methods:<5}] {route.path}")
        count += 1
        
print("========================================================")
print(f"✅ 總共找到 {count} 條規則。")
print("========================================================\n")
