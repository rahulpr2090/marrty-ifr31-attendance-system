/**
 * state_machine.cpp — Firmware state machine implementation
 *
 * States: INIT → IDLE → CAPTURE → UPLOAD → RESULT → IDLE
 *                 ↓ (offline)         ↓ (error)
 *              (queue scan)       ERROR_STATE → IDLE
 *
 * Background tasks in IDLE:
 *   - WiFi reconnect (every 30s if disconnected)
 *   - Queue sync (when WiFi restores)
 *   - Clock update (every 1s)
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "state_machine.h"
#include "config.h"
#include "display.h"
#include "camera.h"
#include "buzzer.h"
#include "touch.h"
#include "wifi_mgr.h"
#include "api_client.h"
#include "offline_queue.h"
#include <time.h>

static State         _state              = State::INIT;
static unsigned long _stateEnteredMs     = 0;
static unsigned long _lastClockUpdateMs  = 0;
static unsigned long _lastWifiRetryMs    = 0;
static bool          _wasOffline         = false;
static bool          _idleDrawn          = false;

// ── IST time helpers ──────────────────────────────────

static void syncNtp() {
  configTime(NTP_OFFSET_SEC, 0, NTP_SERVER);
  DBG("Syncing NTP...\n");
  struct tm ti;
  int retries = 0;
  while (!getLocalTime(&ti) && retries < 10) {
    delay(500);
    retries++;
  }
  DBG("NTP synced: %02d:%02d:%02d\n", ti.tm_hour, ti.tm_min, ti.tm_sec);
}

static void getTimeStr(char* buf, size_t len) {
  struct tm ti;
  if (getLocalTime(&ti)) {
    snprintf(buf, len, "%02d:%02d", ti.tm_hour, ti.tm_min);
  } else {
    strncpy(buf, "--:--", len);
  }
}

static void getSessionStr(char* buf, size_t len) {
  struct tm ti;
  if (!getLocalTime(&ti)) {
    strncpy(buf, "Morning", len);
    return;
  }
  int h = ti.tm_hour;
  if (h < 10)      strncpy(buf, "Morning",   len);
  else if (h < 12) strncpy(buf, "Interval",  len);
  else if (h < 15) strncpy(buf, "Afternoon", len);
  else             strncpy(buf, "Evening",   len);
}

// ── State transitions ─────────────────────────────────

static void enterState(State s) {
  _state          = s;
  _stateEnteredMs = millis();
  DBG("State → %d\n", (int)s);
}

// ── State handlers ────────────────────────────────────

static void handleInit() {
  Display::showWifiConnecting();
  WifiMgr::connect(WIFI_SSID, WIFI_PASSWORD);

  if (WifiMgr::isConnected()) {
    syncNtp();
    if (OfflineQueue::getQueueSize() > 0) {
      DBG("Syncing %d queued scans on boot...\n", OfflineQueue::getQueueSize());
      OfflineQueue::syncQueue();
    }
  } else {
    DBG("No WiFi on boot — entering offline idle\n");
  }

  _idleDrawn = false;
  enterState(State::IDLE);
}

static void handleIdle() {
  char timeStr[8], sessionStr[12];
  getTimeStr(timeStr, sizeof(timeStr));
  getSessionStr(sessionStr, sizeof(sessionStr));

  unsigned long now = millis();

  // Full redraw on first entry
  if (!_idleDrawn) {
    Display::showIdle(sessionStr, timeStr);
    _idleDrawn = true;
    _lastClockUpdateMs = now;
  }

  // Clock tick every second
  if (now - _lastClockUpdateMs >= IDLE_CLOCK_UPDATE_MS) {
    Display::updateIdleClock(timeStr);
    _lastClockUpdateMs = now;
  }

  // WiFi reconnect background task
  if (!WifiMgr::isConnected()) {
    _wasOffline = true;
    if (now - _lastWifiRetryMs >= WIFI_RETRY_INTERVAL_MS) {
      _lastWifiRetryMs = now;
      WifiMgr::reconnect();
    }
  } else if (_wasOffline && WifiMgr::isConnected()) {
    _wasOffline = false;
    // Re-sync queue on reconnect
    if (OfflineQueue::getQueueSize() > 0) {
      OfflineQueue::syncQueue();
    }
    _idleDrawn = false; // Force full redraw to restore WiFi indicator
  }

  // Touch detection
  if (Touch::isTouched()) {
    enterState(State::CAPTURE);
  }
}

static void handleCapture() {
  Buzzer::scanBeep();
  Display::showScanning();

  uint8_t* jpegBuf = nullptr;
  size_t   jpegLen = 0;

  if (!Camera::captureJpeg(&jpegBuf, &jpegLen)) {
    Camera::releaseFrame();
    enterState(State::ERROR_STATE);
    // Store error message for display
    Display::showError("Camera Error");
    Buzzer::errorBeep();
    delay(RESULT_DISPLAY_MS);
    _idleDrawn = false;
    enterState(State::IDLE);
    return;
  }

  if (!WifiMgr::isConnected()) {
    // Save to offline queue
    bool queued = OfflineQueue::saveToQueue(jpegBuf, jpegLen);
    Camera::releaseFrame();
    int qSize = OfflineQueue::getQueueSize();
    Display::showOffline(qSize);
    Buzzer::alreadyMarkedBeep();
    delay(RESULT_DISPLAY_MS);
    _idleDrawn = false;
    enterState(State::IDLE);
    return;
  }

  // Proceed to upload — store frame pointer globally for UPLOAD state
  // (We cheat: just transition immediately since we have the buffer)
  Display::showProcessing();

  AttendanceResult result = ApiClient::markAttendance(jpegBuf, jpegLen);
  Camera::releaseFrame();

  // ── RESULT handling ────────────────────────────
  if (!result.success) {
    Display::showError(result.errorMsg.c_str());
    Buzzer::errorBeep();
    // Queue for retry
    // (image already freed — can't re-queue; retry next scan)
    delay(RESULT_DISPLAY_MS);
    _idleDrawn = false;
    enterState(State::IDLE);
    return;
  }

  const String& status = result.status;

  if (status == "Present" || status == "Late") {
    Display::showSuccess(
      result.studentName.c_str(),
      result.sessionName.c_str(),
      result.date.c_str(),
      result.time.c_str(),
      result.streak,
      result.emotion.c_str()
    );
    Buzzer::successBeep();
  } else if (status == "Already Marked") {
    Display::showAlreadyMarked(result.studentName.c_str());
    Buzzer::alreadyMarkedBeep();
  } else if (status == "Spoofing") {
    Display::showSpoofing();
    Buzzer::spoofBeep();
  } else if (status == "Unknown") {
    Display::showUnknown();
    Buzzer::errorBeep();
  } else {
    // "Error", "OutOfZone", etc.
    String msg = result.errorMsg.length() > 0 ? result.errorMsg : status;
    Display::showError(msg.c_str());
    Buzzer::errorBeep();
  }

  delay(RESULT_DISPLAY_MS);
  _idleDrawn = false;
  enterState(State::IDLE);
}

// ── Public API ────────────────────────────────────────

namespace StateMachine {

void begin() {
  enterState(State::INIT);
}

void run() {
  switch (_state) {
    case State::INIT:       handleInit();    break;
    case State::IDLE:       handleIdle();    break;
    case State::CAPTURE:    handleCapture(); break;
    // UPLOAD and RESULT are handled inline in CAPTURE for simplicity
    case State::UPLOAD:     enterState(State::IDLE); break;
    case State::RESULT:     enterState(State::IDLE); break;
    case State::ERROR_STATE:
      delay(RESULT_DISPLAY_MS);
      _idleDrawn = false;
      enterState(State::IDLE);
      break;
  }
}

State getState() { return _state; }

} // namespace StateMachine
