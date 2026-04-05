/**
 * wifi_mgr.cpp — WiFi manager with exponential backoff reconnect
 *
 * Backoff: 1s → 2s → 4s → 8s → max 30s
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "wifi_mgr.h"
#include "config.h"
#include <WiFi.h>

static unsigned long _nextRetryMs = 0;
static uint32_t      _backoffMs   = 1000;

namespace WifiMgr {

void connect(const char* ssid, const char* password) {
  DBG("WiFi connecting to %s...\n", ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > WIFI_CONNECT_TIMEOUT_MS) {
      DBG("WiFi connect timeout\n");
      return;
    }
    delay(300);
  }

  _backoffMs = 1000; // Reset backoff on success
  DBG("WiFi connected: %s  RSSI: %d dBm\n",
      WiFi.localIP().toString().c_str(), WiFi.RSSI());
}

bool isConnected() {
  return WiFi.status() == WL_CONNECTED;
}

// Non-blocking reconnect — call this in loop()
// Only attempts reconnect when the backoff timer expires
void reconnect() {
  if (isConnected()) {
    _backoffMs = 1000;
    return;
  }

  unsigned long now = millis();
  if (now < _nextRetryMs) return;

  DBG("WiFi reconnecting (backoff %ums)...\n", _backoffMs);
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  // Schedule next attempt with backoff (cap at 30s)
  _backoffMs = min(_backoffMs * 2, (uint32_t)30000);
  _nextRetryMs = now + _backoffMs;
}

int getSignalStrength() {
  return WiFi.RSSI();
}

} // namespace WifiMgr
