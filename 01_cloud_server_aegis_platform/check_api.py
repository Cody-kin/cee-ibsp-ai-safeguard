import sys
import os
# 將 app 目錄加入系統路徑，以便載入 main.py
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend', 'app'))

try:
    from main import app
    from fastapi.routing import APIRoute
    
    print("\n========================================================")
    print("🚀 目前伺服器 (FastAPI) 實際運作中的 API 接收規則：")
    print("========================================================")
    
    count = 0
    for route in app.routes:
        if isinstance(route, APIRoute):
            methods = ",".join(route.methods)
            # 標示出顏色，方便閱讀 (GET 綠色, POST 藍色, PUT 黃色)
            method_str = f"[{methods}]"
            print(f"{method_str:<10} {route.path}")
            count += 1
            
    print("========================================================")
    print(f"✅ 總共找到 {count} 條規則。")
    print("========================================================\n")
except Exception as e:
    print(f"❌ 解析 API 路由時發生錯誤: {e}")
