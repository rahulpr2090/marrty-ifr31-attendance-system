/**
 * config.h — Marrty IFR31 Firmware Configuration
 *
 * SETUP: Update WIFI, API_BASE_URL, and API_KEY before flashing.
 * These values come from your CDK deployment output.
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once

// ── Firmware ────────────────────────────────────────
#define FIRMWARE_VERSION  "1.1.0"
#define DEVICE_ID         "MARRTY-001"
#define DEBUG_MODE        true

// ── WiFi ─────────────────────────────────────────────
#define WIFI_SSID         "YOUR_WIFI_SSID"
#define WIFI_PASSWORD     "YOUR_WIFI_PASSWORD"

// ── API ──────────────────────────────────────────────
// Paste your CDK ApiUrl output here
#define API_BASE_URL      "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/api"
// Paste your API Gateway key here (from AWS Console > API Gateway > API Keys)
#define API_KEY           "YOUR_API_KEY"

// ── NTP / Time ──────────────────────────────────────
#define NTP_SERVER        "pool.ntp.org"
#define NTP_OFFSET_SEC    19800   // IST = UTC+5:30

// ── GPIO Pins ───────────────────────────────────────
#define TFT_CS    1
#define TFT_DC    2
#define TFT_RST   3
#define TFT_SCK   7
#define TFT_SDA   9

#define BUZZER_PIN    5
#define TOUCH_PIN     D5  // GPIO 44 on XIAO ESP32S3

// ── Camera ──────────────────────────────────────────
#define CAM_JPEG_QUALITY  12      // 0 (best) – 63 (worst); 12 ≈ 35–50 KB
#define CAM_FRAME_SIZE    FRAMESIZE_QVGA  // 320×240

// ── Display ─────────────────────────────────────────
#define TFT_WIDTH   128
#define TFT_HEIGHT  160

// ── Touch ───────────────────────────────────────────
#define TOUCH_DEBOUNCE_MS  300

// ── Offline Queue ────────────────────────────────────
#define QUEUE_MAX_SCANS    30
#define QUEUE_DIR          "/queue"

// ── Timeouts / Timers ────────────────────────────────
#define WIFI_CONNECT_TIMEOUT_MS  15000
#define API_TIMEOUT_MS            8000
#define RESULT_DISPLAY_MS         3000
#define IDLE_CLOCK_UPDATE_MS      1000
#define WIFI_RETRY_INTERVAL_MS   30000
#define QUEUE_SYNC_DELAY_MS       2000
#define WARMUP_FRAMES             3

// ── Debug ────────────────────────────────────────────
#if DEBUG_MODE
  #define DBG(...) Serial.printf("[DBG] " __VA_ARGS__)
#else
  #define DBG(...)
#endif
