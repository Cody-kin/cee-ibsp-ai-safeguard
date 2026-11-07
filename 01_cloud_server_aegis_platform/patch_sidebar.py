import os
import re

file_path = "frontend/src/components/Sidebar.tsx"

if not os.path.exists(file_path):
    print(f"❌ 找不到檔案: {file_path}")
    exit(1)

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. 自動把 CloudUpload 圖示加入 lucide-react 的 import 列表中
if "CloudUpload" not in content:
    content = re.sub(r'(import\s+\{[^}]*?)(\}\s+from\s+[\'"]lucide-react[\'"])', r'\1, CloudUpload \2', content)

# 2. 在 /devices 選單的正下方，插入 /ota 選單
if 'href="/ota"' not in content:
    lines = content.split('\n')
    new_lines = []
    for line in lines:
        new_lines.append(line)
        # 找到 devices 那一行，並在下一行插入 ota
        if 'href="/devices"' in line:
            # 完美複製上一行的縮排空格，保持程式碼整齊
            indent = line[:len(line) - len(line.lstrip())]
            new_lines.append(f"{indent}<NavItem href=\"/ota\" icon={{CloudUpload}} label=\"OTA 升級\" active={{pathname === '/ota'}} />")
    content = '\n'.join(new_lines)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Sidebar 選單更新完成！已成功加入 OTA 升級按鈕。")
