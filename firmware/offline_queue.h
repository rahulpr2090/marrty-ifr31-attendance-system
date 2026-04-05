/**
 * offline_queue.h — LittleFS-based offline scan queue
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

namespace OfflineQueue {
  bool begin();                               // Init LittleFS, create /queue dir
  bool saveToQueue(const uint8_t* data, size_t len); // Save scan to flash
  int  getQueueSize();                        // Count queued files
  void syncQueue();                           // Upload all queued scans
}
