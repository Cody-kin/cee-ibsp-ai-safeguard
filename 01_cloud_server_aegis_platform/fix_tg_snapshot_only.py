import os

file_path = "/root/aegis-cloud-platform/backend/tg_core.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 定位要替換的區塊
start_idx = content.find('elif msg == "/snapshot":')
end_idx = content.find('elif msg.startswith("/grant"):', start_idx)

if start_idx != -1 and end_idx != -1:
    new_snapshot_logic = """elif msg == "/snapshot":
                if not nano_ok:
                    send_tg("❌ <b>擷取失敗</b>\\n原因：Vision Node 目前處於<b>離線狀態</b>。", target_chat_id=sender_id)
                elif sys_mode == "sleep":
                    send_tg("⚠️ <b>擷取失敗</b>\\n原因：設備目前處於<b>待命模式</b>，相機已關閉。", target_chat_id=sender_id)
                else:
                    send_tg("📸 <b>正在擷取現場即時畫面...</b>", target_chat_id=sender_id)
                    
                    # 🌟 智能雙重探測：因為不知道後端是用 NANO-001 還是 DEV-NANO-001 存檔，兩個都找！
                    urls_to_try = [
                        "http://127.0.0.1/storage/latest_NANO-001.jpg",
                        "http://127.0.0.1/storage/latest_DEV-NANO-001.jpg"
                    ]
                    
                    success = False
                    for img_url in urls_to_try:
                        try:
                            r = requests.get(f"{img_url}?t={int(time.time())}", timeout=5)
                            if r.status_code == 200:
                                tmp_path = "/tmp/tg_snap.jpg"
                                with open(tmp_path, "wb") as f: f.write(r.content)
                                send_tg("📍 AI-SafeGuard 即時現場畫面\\n(註：此為最後上傳之鏡頭畫面)", tmp_path, target_chat_id=sender_id)
                                success = True
                                break # 找到一張就跳出迴圈
                        except: pass
                        
                    if not success:
                        send_tg("❌ <b>擷取失敗</b>\\n伺服器硬碟中尚未產生最新畫面。這通常是因為 Nano 尚未上傳，或是處於待命狀態。", target_chat_id=sender_id)

            """
    
    # 組合並覆寫
    new_content = content[:start_idx] + new_snapshot_logic + content[end_idx:]
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("✅ TG 機器人 /snapshot 已成功適應目前的後端架構！")
else:
    print("❌ 找不到程式碼區塊，請確認 tg_core.py 格式。")
