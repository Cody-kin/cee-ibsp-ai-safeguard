import time
import threading
import numpy as np  
from modules.DFRobot_DF2301Q import DFRobot_DF2301Q_I2C

class AudioDetector:
    def __init__(self, comms_manager, lora_manager=None):
        self.comms = comms_manager
        self.lora = lora_manager 
        self.module_ready = False
        
        # 🆕 紀錄開機的絕對時間
        self.boot_time = time.time()
        
        try:
            self.df2301q = DFRobot_DF2301Q_I2C(i2c_addr=0x64, bus=1)
            self.df2301q.set_volume(5)
            self.df2301q.set_wake_time(255) 
            self.df2301q.play_by_CMDID(1)
            
            self.module_ready = True
            print("[語音] 🎙️ DFRobot 雙狀態監聽連線成功！(使用 I2C 穩定通訊)")
            
            threading.Thread(target=self._keep_awake_loop, daemon=True).start()
            
        except Exception as e:
            print(f"[語音] ⚠️ 模組連線失敗: {e}")

        if self.module_ready:
            threading.Thread(target=self._listen_loop, daemon=True).start()

    def _keep_awake_loop(self):
        while True:
            time.sleep(200)
            if self.module_ready:
                try:
                    self.df2301q.set_wake_time(255)
                    self.df2301q.play_by_CMDID(1)
                except Exception:
                    pass

    def _listen_loop(self):
        print("[語音] 🛡️ 語音大腦啟動！隨時準備發送 voice_sos 封包")
        
        black_frame = np.zeros((240, 320, 3), dtype=np.uint8)
        
        # 🆕 第一重保險：把硬體裡殘留的舊訊號清空
        for _ in range(3):
            try:
                self.df2301q.get_CMDID()
            except:
                pass
            time.sleep(0.1)

        while True:
            try:
                command_id = self.df2301q.get_CMDID()
                
                if command_id not in [0, 1]:
                    # 🆕 第二重保險：開機前 10 秒內的訊號全部當作幽靈雜訊丟棄！
                    if time.time() - self.boot_time < 10.0:
                        print(f"[語音] 🛑 已攔截並忽略開機幽靈雜訊 (觸發 ID: {command_id})")
                        continue # 跳過這次迴圈，不發送警報

                    if command_id in [2, 5, 6, 9, 255]:
                        print(f"🚨 [語音警報] 偵測到求救訊號 (觸發 ID: {command_id})！")
                        
                        # --- 🚀 【LoRa 實體強制發射】 ---
                        if self.lora is not None and hasattr(self.lora, 'ser') and self.lora.ser is not None and self.lora.ser.is_open:
                            try:
                                lora_payload = b"voice_sos|SOS Voice Alert|critical|Detected human shouting for help\n"
                                self.lora.ser.write(lora_payload)
                                self.lora.ser.flush()
                                print("  [語音] 📡 LoRa 已實體發射求救封包: voice_sos")
                            except Exception as lora_e:
                                print(f"  [語音] ❌ LoRa 實體發射失敗: {lora_e}")

                        # --- 🌐 【網路雲端發射】 ---
                        if hasattr(self.comms, 'send_event_async'):
                            self.comms.send_event_async(
                                cam_id="audio_mic", 
                                event_type="voice_sos",
                                event_name="SOS Voice Alert",
                                severity="critical",
                                description="Detected human shouting for help / 偵測到異常求救語音",
                                frame=black_frame 
                            )
                        time.sleep(5) 
                
                time.sleep(0.1) 
            except Exception as e:
                time.sleep(1)
