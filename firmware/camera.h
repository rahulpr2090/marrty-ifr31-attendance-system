/**
 * camera.h — OV2640 camera driver for XIAO ESP32S3 Sense
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

namespace Camera {
  bool init();
  bool captureJpeg(uint8_t** outBuf, size_t* outLen); // Returns true on success
  void releaseFrame();  // Must call after use to release frame buffer
}
