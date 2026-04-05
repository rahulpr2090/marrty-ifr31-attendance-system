/**
 * wifi_mgr.h — WiFi connection manager with exponential backoff
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

namespace WifiMgr {
  void connect(const char* ssid, const char* password);
  bool isConnected();
  void reconnect();         // Non-blocking: call in loop, uses backoff timer
  int  getSignalStrength(); // Returns RSSI in dBm
}
