from fastapi import APIRouter, Request, Depends
from ..deps import require_admin
from datetime import datetime
from pathlib import Path
import base64
import binascii
import json
import os
import socket
import struct
import time
import traceback

from sqlalchemy.orm import Session

try:
    from app.database import SessionLocal
    from app.models import Event
except Exception:
    from database import SessionLocal
    from models import Event

router = APIRouter(prefix="/api/v1", tags=["lorawan"])

LORA_CMD_DIR = Path("/tmp/aegis_lora_cmds")
HEARTBEAT_DIR = Path("/tmp/aegis_heartbeats")
LATEST_PATH = Path("/tmp/aegis_lora_latest.json")

LORA_CMD_DIR.mkdir(parents=True, exist_ok=True)
HEARTBEAT_DIR.mkdir(parents=True, exist_ok=True)

DEV_EUI = os.getenv("CHIRPSTACK_DEV_EUI", "0000000000000000").lower()
APPLICATION_ID = os.getenv("CHIRPSTACK_APPLICATION_ID", "")
MQTT_PORT = int(os.getenv("CHIRPSTACK_MQTT_PORT", "1883"))
DOWNLINK_FPORT = int(os.getenv("CHIRPSTACK_DOWNLINK_FPORT", "100"))


def now_utc():
    return datetime.utcnow()


def touch_heartbeat(device_id: str):
    try:
        (HEARTBEAT_DIR / f"{device_id}.time").write_text(str(time.time()))
    except Exception:
        pass


def decode_payload(data):
    if data is None:
        return ""

    if not isinstance(data, str):
        return str(data)

    raw = data.strip()
    if raw == "":
        return ""

    # ChirpStack HTTP Integration usually sends base64 in "data".
    try:
        b = base64.b64decode(raw, validate=True)
        return b.decode("utf-8", errors="replace")
    except Exception:
        pass

    # ChirpStack UI often displays hex.
    try:
        b = binascii.unhexlify(raw)
        return b.decode("utf-8", errors="replace")
    except Exception:
        pass

    return raw


def normalize_event_type(raw_type: str):
    t = (raw_type or "").strip()

    mapping = {
        "sys_log": "system_log",
        "system_log": "system_log",
        "ai_vision": "ai_vision",
        "voice_sos": "voice_sos",
        "SEN": "sensor",
        "sen": "sensor",
        "sensor": "sensor",
        "heartbeat": "system_log",
    }

    return mapping.get(t, t or "lorawan")


def parse_node2_payload(payload_text: str):
    """
    Old Node2-compatible format:
    event_type|event_name|severity|description|mq2|mq3
    Example:
    ai_vision|person|critical|test_event|123|456
    """
    text = payload_text or ""
    parts = text.split("|")

    raw_type = parts[0] if len(parts) > 0 and parts[0] else "lorawan"
    event_name = parts[1] if len(parts) > 1 and parts[1] else "uplink"
    severity = parts[2] if len(parts) > 2 and parts[2] else "info"
    description = parts[3] if len(parts) > 3 and parts[3] else text

    mq2 = parts[4] if len(parts) > 4 else None
    mq3 = parts[5] if len(parts) > 5 else None

    if mq2 is not None or mq3 is not None:
        description = f"{description} [Gas:{mq3}/{mq2}]"

    return {
        "device_id": "DEV-LORA-001",
        "raw_type": raw_type,
        "event_type": normalize_event_type(raw_type),
        "event_name": event_name,
        "severity": severity,
        "description": description,
        "mq2": mq2,
        "mq3": mq3,
    }


def save_event(parsed):
    db: Session = SessionLocal()
    try:
        ev = Event(
            device_id=parsed["device_id"],
            event_type=parsed["event_type"],
            event_name=parsed["event_name"],
            severity=parsed["severity"],
            description=parsed["description"],
        )
        db.add(ev)
        db.commit()
        db.refresh(ev)
        return ev.id
    finally:
        db.close()


def get_default_gateway_ip():
    """
    Inside Docker container, this is usually the host bridge gateway.
    Connecting to this IP:1883 can reach ChirpStack Mosquitto exposed on host.
    """
    try:
        with open("/proc/net/route") as f:
            for line in f.readlines()[1:]:
                fields = line.strip().split()
                if len(fields) >= 3 and fields[1] == "00000000":
                    gw_hex = fields[2]
                    return socket.inet_ntoa(struct.pack("<L", int(gw_hex, 16)))
    except Exception:
        pass
    return None


def tcp_check(host, port, timeout=2.0):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True, None
    except Exception as e:
        return False, str(e)


def mqtt_hosts():
    hosts = []

    env_host = os.getenv("CHIRPSTACK_MQTT_HOST")
    if env_host:
        hosts.append(env_host)

    gw = get_default_gateway_ip()
    if gw:
        hosts.append(gw)

    hosts += [
        "host.docker.internal",
        "172.17.0.1",
        "127.0.0.1",
        "chirpstack-docker-mosquitto-1",
        "mosquitto",
        "127.0.0.1",
    ]

    # Deduplicate while keeping order.
    out = []
    for h in hosts:
        if h and h not in out:
            out.append(h)
    return out


def publish_downlink(command: str):
    """
    Publish ChirpStack MQTT downlink.
    Important: only delete pending command if this returns sent=True.
    """
    if not command:
        return {"sent": False, "reason": "empty command"}

    topic = f"application/{APPLICATION_ID}/device/{DEV_EUI}/command/down"

    payload = {
        "devEui": DEV_EUI,
        "confirmed": False,
        "fPort": DOWNLINK_FPORT,
        "data": base64.b64encode(command.encode("utf-8")).decode("ascii"),
    }

    errors = []

    try:
        import paho.mqtt.client as mqtt
    except Exception as e:
        return {
            "sent": False,
            "topic": topic,
            "error": f"paho-mqtt import failed: {e}",
        }

    for host in mqtt_hosts():
        ok, err = tcp_check(host, MQTT_PORT, timeout=2.0)
        if not ok:
            errors.append({"host": host, "stage": "tcp_check", "error": err})
            continue

        try:
            client = mqtt.Client(client_id=f"aegis-lorawan-downlink-{int(time.time())}")
            client.connect(host, MQTT_PORT, keepalive=30)

            result = client.publish(topic, json.dumps(payload), qos=0, retain=False)
            client.disconnect()

            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                return {
                    "sent": True,
                    "host": host,
                    "port": MQTT_PORT,
                    "topic": topic,
                    "command": command,
                    "fPort": DOWNLINK_FPORT,
                }

            errors.append({
                "host": host,
                "stage": "publish",
                "error": f"mqtt publish rc={result.rc}",
            })

        except Exception as e:
            errors.append({
                "host": host,
                "stage": "mqtt",
                "error": str(e),
            })

    return {
        "sent": False,
        "topic": topic,
        "error": "all MQTT hosts failed",
        "errors": errors[-8:],
    }


def consume_pending_command_if_sent():
    cmd_path = LORA_CMD_DIR / "pending.txt"

    if not cmd_path.exists():
        return {"sent": False, "reason": "no pending command"}

    command = cmd_path.read_text().strip()

    if not command:
        try:
            cmd_path.unlink()
        except Exception:
            pass
        return {"sent": False, "reason": "empty pending command removed"}

    result = publish_downlink(command)

    # Very important: do NOT remove command on failure.
    if result.get("sent") is True:
        try:
            cmd_path.unlink()
        except Exception:
            pass
    else:
        result["pending_kept"] = True

    return result


@router.post("/lorawan/uplink")
async def lorawan_uplink(request: Request):
    event = request.query_params.get("event", "up")

    try:
        body = await request.json()
    except Exception:
        body = {}

    device_info = body.get("deviceInfo") or {}
    dev_eui = (device_info.get("devEui") or body.get("devEui") or DEV_EUI).lower()

    payload_text = decode_payload(body.get("data"))
    parsed = parse_node2_payload(payload_text)

    touch_heartbeat("LORA-001")
    touch_heartbeat("DEV-LORA-001")

    event_id = None
    if event == "up":
        event_id = save_event(parsed)

    downlink_result = consume_pending_command_if_sent()

    record = {
        "status": "success",
        "event": event,
        "event_id": event_id,
        "dev_eui": dev_eui,
        "f_port": body.get("fPort"),
        "f_cnt": body.get("fCnt"),
        "dr": body.get("dr"),
        "payload_text": payload_text,
        "parsed": parsed,
        "downlink": downlink_result,
        "received_at": now_utc().isoformat() + "Z",
    }

    LATEST_PATH.write_text(json.dumps(record, ensure_ascii=False, indent=2))
    return record


@router.get("/lorawan/latest")
def lorawan_latest():
    if not LATEST_PATH.exists():
        return {
            "status": "empty",
            "message": "No LoRaWAN uplink received yet",
        }

    return json.loads(LATEST_PATH.read_text())


@router.post("/lorawan/downlink", dependencies=[Depends(require_admin)])
async def lorawan_downlink(request: Request):
    body = await request.json()
    command = body.get("command")

    if not command:
        return {"status": "error", "message": "Missing command"}

    if not command.endswith("\n"):
        command += "\n"

    result = publish_downlink(command)

    return {
        "status": "success" if result.get("sent") else "error",
        "downlink": result,
    }


@router.get("/lorawan/debug", dependencies=[Depends(require_admin)])
def lorawan_debug():
    checks = []
    for host in mqtt_hosts():
        ok, err = tcp_check(host, MQTT_PORT, timeout=1.5)
        checks.append({
            "host": host,
            "port": MQTT_PORT,
            "tcp_ok": ok,
            "error": err,
        })

    pending = None
    pending_path = LORA_CMD_DIR / "pending.txt"
    if pending_path.exists():
        pending = pending_path.read_text().strip()

    return {
        "application_id": APPLICATION_ID,
        "dev_eui": DEV_EUI,
        "mqtt_port": MQTT_PORT,
        "default_gateway_ip": get_default_gateway_ip(),
        "hosts": checks,
        "pending_command": pending,
    }
