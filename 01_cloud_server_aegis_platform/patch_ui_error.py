import os

file_path = "frontend/src/app/devices/page.tsx"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

old_fetch = """    try {
      await fetch('/api/v1/devices/NANO-001/system_command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ command: cmd })
      });
      toast.success(`已下發系統指令: SYS|${cmd}`, { icon: '📡', style: { background: '#172033', color: '#fff' }});
    } catch (e) {
      toast.error('指令發送失敗');
    }"""

new_fetch = """    try {
      const res = await fetch('/api/v1/devices/NANO-001/system_command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ command: cmd })
      });
      if (!res.ok) {
        toast.error(`伺服器拒絕請求 (錯誤碼: ${res.status})`);
        return;
      }
      toast.success(`已下發系統指令: SYS|${cmd}`, { icon: '📡', style: { background: '#172033', color: '#fff' }});
    } catch (e) {
      toast.error('網路連線異常，指令發送失敗');
    }"""

if old_fetch in content:
    content = content.replace(old_fetch, new_fetch)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("✅ 前端錯誤捕捉修補完成！")
else:
    print("⚠️ 找不到指定的字串，可能是已經替換過或排版不同。")
