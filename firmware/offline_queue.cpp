/**
 * offline_queue.cpp — LittleFS scan queue with auto-sync
 *
 * Saves JPEG scans to /queue/scan_NNN.dat when offline.
 * Max 30 scans. Auto-syncs when WiFi reconnects.
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "offline_queue.h"
#include "api_client.h"
#include "config.h"
#include <LittleFS.h>

static int _queueIndex = 0;

namespace OfflineQueue {

bool begin() {
  if (!LittleFS.begin(true)) { // true = format on fail
    DBG("LittleFS mount failed\n");
    return false;
  }

  // Ensure queue directory exists
  if (!LittleFS.exists(QUEUE_DIR)) {
    LittleFS.mkdir(QUEUE_DIR);
  }

  // Find current highest index
  File dir = LittleFS.open(QUEUE_DIR);
  while (true) {
    File f = dir.openNextFile();
    if (!f) break;
    int idx = 0;
    sscanf(f.name(), "scan_%d.dat", &idx);
    if (idx > _queueIndex) _queueIndex = idx;
    f.close();
  }
  dir.close();

  DBG("OfflineQueue ready: %d queued\n", getQueueSize());
  return true;
}

bool saveToQueue(const uint8_t* data, size_t len) {
  int size = getQueueSize();
  if (size >= QUEUE_MAX_SCANS) {
    DBG("Queue full (%d scans)\n", size);
    return false;
  }

  char path[40];
  snprintf(path, sizeof(path), "%s/scan_%04d.dat", QUEUE_DIR, ++_queueIndex);

  File f = LittleFS.open(path, FILE_WRITE);
  if (!f) {
    DBG("Queue write failed: %s\n", path);
    return false;
  }

  // Header: 4-byte timestamp + 4-byte size
  uint32_t now32 = (uint32_t)(millis() / 1000);
  uint32_t len32 = (uint32_t)len;
  f.write((uint8_t*)&now32, 4);
  f.write((uint8_t*)&len32, 4);
  f.write(data, len);
  f.close();

  DBG("Queued scan: %s (%u bytes)\n", path, len);
  return true;
}

int getQueueSize() {
  int count = 0;
  File dir = LittleFS.open(QUEUE_DIR);
  if (!dir) return 0;
  while (true) {
    File f = dir.openNextFile();
    if (!f) break;
    count++;
    f.close();
  }
  dir.close();
  return count;
}

void syncQueue() {
  DBG("Syncing offline queue...\n");
  File dir = LittleFS.open(QUEUE_DIR);
  if (!dir) return;

  while (true) {
    File f = dir.openNextFile();
    if (!f) break;

    String fname = String(QUEUE_DIR) + "/" + f.name();
    size_t fileSize = f.size();
    if (fileSize < 8) { f.close(); LittleFS.remove(fname); continue; }

    // Read header
    uint32_t timestamp, dataLen;
    f.read((uint8_t*)&timestamp, 4);
    f.read((uint8_t*)&dataLen,   4);

    if (dataLen + 8 > fileSize || dataLen == 0) {
      f.close();
      LittleFS.remove(fname);
      continue;
    }

    // Read JPEG data
    uint8_t* buf = (uint8_t*)malloc(dataLen);
    if (!buf) { f.close(); continue; }
    f.read(buf, dataLen);
    f.close();

    DBG("Syncing %s (%u bytes)...\n", fname.c_str(), dataLen);
    AttendanceResult result = ApiClient::markAttendance(buf, dataLen);
    free(buf);

    if (result.success) {
      LittleFS.remove(fname);
      DBG("Sync OK: %s - %s\n", fname.c_str(), result.status.c_str());
    } else {
      DBG("Sync failed: %s\n", result.errorMsg.c_str());
      break; // Stop if network error — will retry next cycle
    }

    delay(QUEUE_SYNC_DELAY_MS);
  }

  dir.close();
  DBG("Queue sync done. Remaining: %d\n", getQueueSize());
}

} // namespace OfflineQueue
