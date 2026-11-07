import serial
import serial.tools.list_ports
import threading
import time
import os
import subprocess
import glob
from datetime import datetime

def debug_log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] 🛠️ [LoRa] {msg}", flush=True)

class LoRaManager:
    def __init__(self, network_manager=None):
        self.ser = None
        self.network = network_manager
        self.lock = threading.Lock()
        self.labels_map = ['fire', 'smoke', 'fall', 'hardhat', 'vest', 'smoking', 'phone']

        debug_log("開始掃描 Node1 / Heltec USB Serial...")

        for port in self._candidate_ports():
            if self._try_open(port):
                break

        if self.ser:
            threading.Thread(target=self._listen_for_commands, daemon=True).start()
            self.send_line("sys_log|boot|info|nano_lora_link_ready")
        else:
            debug_log("🚨 找不到 Node1 / LoRa 模組。請檢查 USB 線、/dev/ttyUSB* 或 /dev/ttyACM*。")

    def _candidate_ports(self):
        ports = []

        env_port = os.getenv("LORA_PORT")
        if env_port:
            ports.append(env_port)

        ports += sorted(glob.glob("/dev/serial/by-id/*"))

        preferred = [
            "/dev/ttyUSB1",
            "/dev/ttyUSB0",
            "/dev/ttyACM0",
            "/dev/ttyACM1",
            "/dev/ttyUSB2",
            "/dev/ttyACM2",
        ]
        ports += preferred

        try:
            for p in serial.tools.list_ports.comports():
                desc = f"{p.device} {p.description} {p.manufacturer}".lower()
                if any(k in desc for k in ["usb", "cp210", "ch340", "heltec", "esp32", "silicon", "wch"]):
                    ports.append(p.device)
        except Exception:
            pass

        out = []
        for p in ports:
            if p and p not in out:
                out.append(p)
        return out

    def _try_open(self, port):
        try:
            ser = serial.Serial(port, 115200, timeout=0.15, write_timeout=1.0)
            time.sleep(0.8)
            try:
                ser.reset_input_buffer()
                ser.reset_output_buffer()
            except Exception:
                pass

            self.ser = ser
            debug_log(f"✅ 成功綁定 Node1 LoRa 模組於: {port}")
            return True

        except Exception as e:
            debug_log(f"略過 {port}: {e}")
            return False

    def send_line(self, line):
        if not self.ser:
            return False

        try:
            line = str(line).replace("\r", " ").replace("\n", " ").strip()
            if not line:
                return False

            with self.lock:
                self.ser.write((line + "\n").encode("utf-8"))
                self.ser.flush()

            debug_log(f"📤 已送往 Node1: {line}")
            return True

        except Exception as e:
            debug_log(f"❌ 發送到 Node1 失敗: {e}")
            return False

    def _extract_command(self, line):
        line = line.strip()
        if not line:
            return None

        idxs = []
        for key in ["SYS|", "CFG|"]:
            i = line.find(key)
            if i >= 0:
                idxs.append(i)

        if not idxs:
            return None

        return line[min(idxs):].strip()

    def _listen_for_commands(self):
        debug_log("👂 開始監聽 Node1 下行指令...")

        while True:
            try:
                if not self.ser:
                    time.sleep(1)
                    continue

                raw_data = self.ser.readline()
                if not raw_data:
                    time.sleep(0.03)
                    continue

                line = raw_data.decode("utf-8", errors="ignore").strip()
                if not line:
                    continue

                cmd = self._extract_command(line)
                if not cmd:
                    continue

                debug_log(f"📥 收到 Node1 指令: {cmd}")

                if cmd.startswith("SYS|STOP"):
                    if self.network:
                        self.network.system_active = False
                    debug_log("🛑 收到 SYS|STOP：關閉 AI 與鏡頭，進入待機")
                    continue

                if cmd.startswith("SYS|START"):
                    if self.network:
                        self.network.system_active = True
                    debug_log("🚀 收到 SYS|START：恢復 AI 與鏡頭")
                    continue

                if cmd.startswith("SYS|OTA_SCRIPT"):
                    debug_log("🚀 收到 SYS|OTA_SCRIPT：開始 OTA 腳本")
                    threading.Thread(target=self._execute_ota_script, daemon=True).start()
                    continue

                if cmd.startswith("CFG|"):
                    self._handle_cfg(cmd)
                    continue

            except Exception as e:
                debug_log(f"⚠️ LoRa 監聽錯誤: {e}")
                time.sleep(1)

    def _handle_cfg(self, cmd):
        try:
            parts = cmd.split("|")
            if len(parts) < 3:
                debug_log(f"⚠️ CFG 格式錯誤: {cmd}")
                return

            cam_id = parts[1].strip()
            flags = parts[2].strip().split(",")

            active_tasks = {}
            for i, flag_str in enumerate(flags):
                try:
                    val = float(flag_str)
                    if 0.0 <= val <= 1.0 and i < len(self.labels_map):
                        active_tasks[self.labels_map[i]] = val
                except ValueError:
                    pass

            if self.network:
                self.network.camera_configs[cam_id] = active_tasks

            detail = ", ".join([f"{k}({v})" for k, v in active_tasks.items()])
            debug_log(f"✨ AI 已套用 {cam_id} 新靈敏度 ➔ [{detail if detail else '無啟動物件'}]")

        except Exception as e:
            debug_log(f"❌ CFG 套用失敗: {e}")

    def _execute_ota_script(self):
        if os.getenv("ALLOW_UNSIGNED_OTA", "0") != "1":
            debug_log("Unsigned OTA is disabled; verify payloads before explicit lab opt-in")
            return
        script_url = "http://127.0.0.1/api/v1/ota/update.sh"
        local_script = "/tmp/aegis_update.sh"

        try:
            if self.network:
                self.network.system_active = False

            debug_log("🛑 OTA 前置：關閉 AI 與鏡頭")
            time.sleep(2)

            debug_log(f"📥 下載 OTA 腳本: {script_url}")
            subprocess.run(["wget", "-q", script_url, "-O", local_script], check=True, timeout=30)
            subprocess.run(["chmod", "+x", local_script], check=True)

            debug_log("⚙️ 執行 OTA 腳本...")
            result = subprocess.run(
                ["bash", local_script],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
                timeout=60
            )

            stdout_str = result.stdout.decode("utf-8", errors="ignore")
            log_output = stdout_str[:200]
            debug_log(f"✅ OTA 腳本完成:\n{stdout_str}")

            if self.network:
                self.network.system_active = True
                self.network.send_event_async(
                    cam_id="NANO-001",
                    event_type="system_log",
                    event_name="OTA Success",
                    severity="info",
                    description=f"Output: {log_output}",
                    frame=None
                )

                self.network.system_active = False

            time.sleep(3)
            debug_log("🔄 OTA 完成，結束當前程序")
            os._exit(0)

        except subprocess.TimeoutExpired:
            debug_log("❌ OTA 腳本超時")
            if self.network:
                self.network.system_active = True
                self.network.send_event_async(
                    cam_id="NANO-001",
                    event_type="system_log",
                    event_name="OTA Error",
                    severity="critical",
                    description="Script Timeout > 60s",
                    frame=None
                )

        except subprocess.CalledProcessError as e:
            stderr_str = e.stderr.decode("utf-8", errors="ignore") if e.stderr else ""
            debug_log(f"❌ OTA 腳本失敗: {stderr_str}")
            if self.network:
                self.network.system_active = True
                self.network.send_event_async(
                    cam_id="NANO-001",
                    event_type="system_log",
                    event_name="OTA Error",
                    severity="critical",
                    description=f"Bash Error: {stderr_str[:150]}",
                    frame=None
                )

        except Exception as e:
            debug_log(f"❌ OTA 系統錯誤: {e}")
            if self.network:
                self.network.system_active = True
                self.network.send_event_async(
                    cam_id="NANO-001",
                    event_type="system_log",
                    event_name="OTA Error",
                    severity="critical",
                    description=f"System Error: {str(e)}",
                    frame=None
                )
