#include "LoRaWan_APP.h"
#include <Wire.h>
#include "HT_SSD1306Wire.h"

// =====================================================
// Aegis Node1 Final - OLED Fixed Version
// Jetson Nano USB Serial  <->  Heltec Wireless Stick V3  <->  LoRaWAN
//
// Uplink keeps old Node2 API payload rule:
//   type|event_name|severity|description|mq2|mq3
//
// Downlink keeps old server command rule:
//   CFG|...
//   SYS|START
//   SYS|STOP
//   SYS|OTA_SCRIPT
//
// Arduino IDE:
//   Board: Heltec Wireless Stick(V3)
//   LoRaWAN Region: AS923
//   USB CDC On Boot: Enabled
//   Serial Monitor: 115200
// =====================================================

// 0 = Production mode: Serial is reserved for Jetson Nano.
 //     Node1 will send ONLY server commands such as CFG|... / SYS|... to Nano.
 //     Set Arduino Tools -> LoRaWAN Debug Level to NONE/OFF if available.
// 1 = Debug mode: Serial Monitor debug enabled. Do NOT connect Nano while debug is 1.
#define DEBUG_SERIAL 0

#if DEBUG_SERIAL
  #define DBG_PRINT(x) Serial.print(x)
  #define DBG_PRINTLN(x) Serial.println(x)
#else
  #define DBG_PRINT(x)
  #define DBG_PRINTLN(x)
#endif

// =====================================================
// Pins
// =====================================================
// Keep these as your previous Node1 wiring.
// If your MQ sensors are connected to other ADC pins, change here.
#define MQ2_PIN 1
#define MQ3_PIN 2

// =====================================================
// OLED / Vext power fix
// Wireless Stick V3 OLED often stays black if Vext power is not enabled.
// Heltec boards usually use LOW = Vext ON, HIGH = Vext OFF.
// =====================================================
static SSD1306Wire display(
  0x3c,
  500000,
  SDA_OLED,
  SCL_OLED,
  GEOMETRY_64_32,
  RST_OLED
);

void oledPowerOnFast() {
  // IMPORTANT:
  // Do not put delay() here. LoRaWAN Join RX windows are timing-sensitive.
  // Vext is enabled once during setup, then we only keep it LOW.
  pinMode(Vext, OUTPUT);
  digitalWrite(Vext, LOW);   // LOW = ON for Heltec Vext
}

void oledPowerOff() {
  pinMode(Vext, OUTPUT);
  digitalWrite(Vext, HIGH);  // HIGH = OFF
}

void oledHardReset() {
  pinMode(RST_OLED, OUTPUT);
  digitalWrite(RST_OLED, LOW);
  delay(30);
  digitalWrite(RST_OLED, HIGH);
  delay(100);
}

void oledInitFixed() {
  // Initial power-up delay is OK in setup only.
  pinMode(Vext, OUTPUT);
  digitalWrite(Vext, LOW);
  delay(150);

  oledHardReset();

  Wire.begin(SDA_OLED, SCL_OLED);
  delay(50);

  display.init();
  display.clear();
  display.setContrast(255);
  display.setTextAlignment(TEXT_ALIGN_LEFT);
  display.setFont(ArialMT_Plain_10);

  display.drawString(0, 0, "OLED OK");
  display.drawString(0, 10, "Aegis Node1");
  display.drawString(0, 20, "Booting...");
  display.display();

  delay(700);
}

void oledShow(String line1, String line2 = "", String line3 = "") {
  // No delay here. Display update must not shift LoRaWAN RX timing.
  oledPowerOnFast();

  display.clear();
  display.setTextAlignment(TEXT_ALIGN_LEFT);
  display.setFont(ArialMT_Plain_10);

  display.drawString(0, 0, line1.substring(0, 12));
  display.drawString(0, 10, line2.substring(0, 12));
  display.drawString(0, 20, line3.substring(0, 12));

  display.display();
}

// =====================================================
// ChirpStack OTAA keys
// DevEUI:  00000000000000000000000000000000
// JoinEUI: 00000000000000000000000000000000
// AppKey:  00000000000000000000000000000000
// =====================================================
uint8_t devEui[] = {0}; // Provision locally; original credentials removed.

uint8_t appEui[] = {0}; // Provision locally; original credentials removed.

uint8_t appKey[] = {0}; // Provision locally; original credentials removed.

// ABP placeholders, not used but required by the Heltec LoRaWAN template.
uint8_t nwkSKey[] = {0}; // Provision locally; original credentials removed.

uint8_t appSKey[] = {0}; // Provision locally; original credentials removed.

uint32_t devAddr = 0;

// =====================================================
// LoRaWAN config
// =====================================================
// AS923 ch0/ch1: 923.2 / 923.4 MHz join channels.
uint16_t userChannelsMask[6] = {
  0x0003, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
};

LoRaMacRegion_t loraWanRegion = ACTIVE_REGION;

// Class A is stable. Server downlink will arrive after uplink RX windows.
// Keep heartbeat short to make commands feel near real-time.
DeviceClass_t loraWanClass = CLASS_A;

bool overTheAirActivation = true;
bool loraWanAdr = false;
bool isTxConfirmed = false;

uint8_t appPort = 2;
uint8_t confirmedNbTrials = 4;

// Heartbeat interval: short for command responsiveness.
// For final long-term deployment you may change to 10000 / 15000 / 30000.
uint32_t appTxDutyCycle = 5000;

// DR3 gives more payload room. If signal is weak, change to 2.
uint8_t defaultDataRate = 2;

// Keep payload small enough for LoRaWAN.
const int MAX_LW_PAYLOAD = 90;

// =====================================================
// Runtime state
// =====================================================
String queuedPayload = "";
bool hasQueuedPayload = false;
bool joinedOnce = false;

unsigned long lastHeartbeatMs = 0;
uint32_t txCounter = 0;
uint32_t joinTryCounter = 0;

String lastNanoLine = "Wait AI";
String lastDownlink = "None";

int currentMq2 = 0;
int currentMq3 = 0;

// =====================================================
// String helpers
// =====================================================
String getField(String data, char sep, int index) {
  int found = 0;
  int start = 0;

  for (int i = 0; i <= data.length(); i++) {
    if (i == data.length() || data.charAt(i) == sep) {
      if (found == index) {
        return data.substring(start, i);
      }
      found++;
      start = i + 1;
    }
  }

  return "";
}

int countSep(String data, char sep) {
  int n = 0;
  for (int i = 0; i < data.length(); i++) {
    if (data.charAt(i) == sep) n++;
  }
  return n;
}

String cleanLine(String s) {
  s.replace("\r", "");
  s.replace("\n", "");
  s.trim();
  return s;
}

// Convert Nano message into old Node2-compatible payload:
//   type|event_name|severity|description|mq2|mq3
String normalizeNanoToNode2Payload(String nanoMsg) {
  nanoMsg = cleanLine(nanoMsg);

  currentMq2 = analogRead(MQ2_PIN);
  currentMq3 = analogRead(MQ3_PIN);

  String type, eventName, severity, desc;

  // If Nano already sends old style:
  // ai_vision|person|critical|description
  // sys_log|boot|info|nano_started
  if (countSep(nanoMsg, '|') >= 3) {
    type = getField(nanoMsg, '|', 0);
    eventName = getField(nanoMsg, '|', 1);
    severity = getField(nanoMsg, '|', 2);
    desc = getField(nanoMsg, '|', 3);
  } else {
    // Fallback for simple YOLO lines:
    // "critical person 0.92"
    // "fire detected"
    String lower = nanoMsg;
    lower.toLowerCase();

    type = "ai_vision";

    if (lower.indexOf("fire") >= 0) eventName = "fire";
    else if (lower.indexOf("fall") >= 0) eventName = "fall";
    else if (lower.indexOf("person") >= 0) eventName = "person";
    else if (lower.indexOf("smoke") >= 0) eventName = "smoke";
    else eventName = "ai_event";

    if (lower.indexOf("critical") >= 0 || lower.indexOf("danger") >= 0) {
      severity = "critical";
    } else if (lower.indexOf("high") >= 0 || lower.indexOf("warning") >= 0 || lower.indexOf("alert") >= 0) {
      severity = "high";
    } else {
      severity = "info";
    }

    desc = nanoMsg;
  }

  if (type.length() == 0) type = "ai_vision";
  if (eventName.length() == 0) eventName = "ai_event";
  if (severity.length() == 0) severity = "info";
  if (desc.length() == 0) desc = "no_desc";

  // Avoid using "|" inside description, because server uses "|" to parse.
  desc.replace("|", "_");

  String suffix = "|" + String(currentMq2) + "|" + String(currentMq3);
  String head = type + "|" + eventName + "|" + severity + "|";

  int maxDescLen = MAX_LW_PAYLOAD - head.length() - suffix.length();
  if (maxDescLen < 0) maxDescLen = 0;

  if (desc.length() > maxDescLen) {
    desc = desc.substring(0, maxDescLen);
  }

  return head + desc + suffix;
}

String makeHeartbeatPayload() {
  currentMq2 = analogRead(MQ2_PIN);
  currentMq3 = analogRead(MQ3_PIN);

  String payload =
    "sys_log|heartbeat|info|node1_alive_" +
    String(txCounter) + "|" +
    String(currentMq2) + "|" +
    String(currentMq3);

  if (payload.length() > MAX_LW_PAYLOAD) {
    payload = payload.substring(0, MAX_LW_PAYLOAD);
  }

  return payload;
}

void queuePayload(String payload) {
  if (payload.length() > MAX_LW_PAYLOAD) {
    payload = payload.substring(0, MAX_LW_PAYLOAD);
  }

  queuedPayload = payload;
  hasQueuedPayload = true;

  String eventName = getField(payload, '|', 1);
  String severity = getField(payload, '|', 2);

  oledShow("Queue TX", eventName, severity);
  DBG_PRINTLN("[QUEUE] " + payload);

  // If joined, request TX as soon as possible.
  if (joinedOnce) {
    deviceState = DEVICE_STATE_SEND;
  }
}

// =====================================================
// Downlink callback from Heltec LoRaWAN stack
// Called when ChirpStack sends CFG|... or SYS|... downlink.
// =====================================================
void downLinkDataHandle(McpsIndication_t *mcpsIndication) {
  if (mcpsIndication == NULL || mcpsIndication->BufferSize == 0) {
    return;
  }

  String cmd = "";

  for (uint8_t i = 0; i < mcpsIndication->BufferSize; i++) {
    char c = (char)mcpsIndication->Buffer[i];

    // Keep normal printable chars only.
    if (c >= 32 && c <= 126) {
      cmd += c;
    }
  }

  cmd = cleanLine(cmd);

  if (cmd.length() == 0) {
    return;
  }

  lastDownlink = cmd;

  oledShow("RX Command", cmd, "To Nano");

  // Forward only valid old commands to Jetson Nano over USB Serial.
  // This keeps old Node2 command rules.
  if (cmd.startsWith("CFG|") || cmd.startsWith("SYS|")) {
    Serial.println(cmd);
  }

#if DEBUG_SERIAL
  Serial.print("[DOWNLINK] Port ");
  Serial.print(mcpsIndication->Port);
  Serial.print(" Data: ");
  Serial.println(cmd);
#endif
}

// =====================================================
// LoRaWAN prepare frame
// =====================================================
static void prepareTxFrame(uint8_t port) {
  String msg;

  if (hasQueuedPayload) {
    msg = queuedPayload;
    hasQueuedPayload = false;
  } else {
    msg = makeHeartbeatPayload();
  }

  if (msg.length() > MAX_LW_PAYLOAD) {
    msg = msg.substring(0, MAX_LW_PAYLOAD);
  }

  appDataSize = msg.length();

  for (int i = 0; i < appDataSize; i++) {
    appData[i] = msg[i];
  }

  txCounter++;

  String eventName = getField(msg, '|', 1);
  String severity = getField(msg, '|', 2);

  oledShow("TX LoRaWAN", eventName, severity);
  DBG_PRINTLN("[LoRaWAN TX] " + msg);
}

// =====================================================
// Setup
// =====================================================
void setup() {
  Serial.begin(115200);
  Serial.setTimeout(30);
  delay(1200);

  pinMode(MQ2_PIN, INPUT);
  pinMode(MQ3_PIN, INPUT);

  // Initialize Heltec board.
  Mcu.begin(HELTEC_BOARD, SLOW_CLK_TPYE);

  // Important: enable Vext first, then initialize OLED.
  oledInitFixed();

  oledShow("Aegis Node1", "LoRaWAN", "Booting");

  DBG_PRINTLN("Aegis Node1 Production - Nano USB Serial + LoRaWAN");
  DBG_PRINTLN("Set Arduino Tools -> LoRaWAN Region: AS923");
  DBG_PRINTLN("Production build: USB Serial reserved for Jetson Nano.");
}

// =====================================================
// Main loop
// =====================================================
void loop() {
  // 1) Read YOLO / system message from Jetson Nano over USB Serial.
  // Nano should send one line, examples:
  //   ai_vision|fire|critical|fire_detected_conf_0.92
  //   voice_sos|help|high|worker_pressed_sos
  //   SEN|gas|high|mq_warning
  //   sys_log|boot|info|nano_started
  if (Serial.available() > 0) {
    String nanoMsg = Serial.readStringUntil('\n');
    nanoMsg = cleanLine(nanoMsg);

    if (
      nanoMsg.length() > 0 &&
      !nanoMsg.startsWith("CFG|") &&
      !nanoMsg.startsWith("SYS|")
    ) {
      lastNanoLine = nanoMsg;

      String payload = normalizeNanoToNode2Payload(nanoMsg);
      queuePayload(payload);

      oledShow("Nano RX", getField(payload, '|', 1), getField(payload, '|', 2));
    }
  }

  // 2) Heartbeat uplink keeps LoRa card online and opens Class A downlink windows.
  if (joinedOnce && !hasQueuedPayload && millis() - lastHeartbeatMs >= appTxDutyCycle) {
    lastHeartbeatMs = millis();
    queuePayload(makeHeartbeatPayload());
  }

  // 3) LoRaWAN state machine.
  switch (deviceState) {
    case DEVICE_STATE_INIT: {
// Force manual DevEUI from devEui[] above.
      // Do NOT call LoRaWAN.generateDeveuiByChipID(), otherwise ChirpStack
      // will not match the registered DevEUI.
      oledShow("LoRaWAN", "Init", "AS923");

      LoRaWAN.init(loraWanClass, loraWanRegion);
      LoRaWAN.setDefaultDR(defaultDataRate);

      break;
    }

    case DEVICE_STATE_JOIN: {
      joinTryCounter++;
      oledShow("Joining", "Try " + String(joinTryCounter), "AS923 DR2");
      DBG_PRINTLN("[LoRaWAN] Joining try " + String(joinTryCounter));
      LoRaWAN.join();

      break;
    }

    case DEVICE_STATE_SEND: {
      joinedOnce = true;

      prepareTxFrame(appPort);
      LoRaWAN.send();

      deviceState = DEVICE_STATE_CYCLE;
      break;
    }

    case DEVICE_STATE_CYCLE: {
      // Short cycle; the queue / heartbeat logic decides actual payload content.
      txDutyCycleTime = 2000 + randr(
        -APP_TX_DUTYCYCLE_RND,
        APP_TX_DUTYCYCLE_RND
      );

      LoRaWAN.cycle(txDutyCycleTime);
      deviceState = DEVICE_STATE_SLEEP;

      break;
    }

    case DEVICE_STATE_SLEEP: {
      // Do not call any OLED function or delay before LoRaWAN.sleep().
      // JoinAccept RX windows are timing-sensitive.
      LoRaWAN.sleep(loraWanClass);

      break;
    }

    default: {
      deviceState = DEVICE_STATE_INIT;
      break;
    }
  }
}
