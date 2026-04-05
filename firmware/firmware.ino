/**
 * firmware.ino — Marrty IFR31 Attendance Scanner
 *
 * Hardware:  Seeed XIAO ESP32S3 Sense
 * Display:   ST7735 TFT 128×160 (Hardware SPI)
 * Camera:    OV2640 (internal, on-board)
 * Buzzer:    Passive piezo on GPIO5 (LEDC ch2)
 * Touch:     Capacitive sensor on D5
 *
 * Required Arduino Libraries:
 *   - Adafruit GFX Library (by Adafruit)
 *   - Adafruit ST7735 and ST7789 Library (by Adafruit)
 *   - ArduinoJson (by Benoit Blanchon)
 *   - ESP32 Arduino package (Espressif)
 *     (includes: HTTPClient, WiFiClientSecure, LittleFS, esp_camera)
 *
 * Board:     Seeed XIAO ESP32S3 Sense
 * Partition: "Huge APP" (for camera + LittleFS)
 *
 * Version: 1.1.0
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "config.h"
#include "display.h"
#include "camera.h"
#include "buzzer.h"
#include "touch.h"
#include "wifi_mgr.h"
#include "offline_queue.h"
#include "state_machine.h"

void setup() {
  Serial.begin(115200);
  delay(200);
  DBG("\n\n=== Marrty IFR31 v%s ===\n", FIRMWARE_VERSION);
  DBG("Device: %s\n", DEVICE_ID);

  // ── Initialize hardware in dependency order ────────────
  Display::init();          // TFT first — show status during boot
  Buzzer::init();           // LEDC channel 2 (NOT 0 — camera needs ch0)
  Touch::init();            // INPUT_PULLDOWN, rising edge

  if (!Camera::init()) {    // OV2640 on LEDC ch0
    Display::showError("Camera Init Failed");
    // Don't halt — can still run without camera for display testing
  }

  if (!OfflineQueue::begin()) { // LittleFS flash queue
    DBG("OfflineQueue init failed\n");
    // Non-fatal — will just drop scans if offline
  }

  // ── Start state machine ──────────────────────────────────
  StateMachine::begin(); // Will connect WiFi and sync NTP in INIT state
}

void loop() {
  StateMachine::run();
}
