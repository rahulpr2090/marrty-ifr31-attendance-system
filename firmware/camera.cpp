/**
 * camera.cpp — OV2640 driver for XIAO ESP32S3 Sense
 *
 * Uses the internal ESP32S3 camera pin mapping (not GPIO numbers — fixed silicon routing).
 * Captures JPEG at QVGA (320×240) targeting < 50 KB for fast API upload.
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "camera.h"
#include "config.h"
#include "esp_camera.h"

// ── XIAO ESP32S3 Sense internal camera pin map ──────
// These are FIXED by the PCB — they are not user-configurable
#define CAM_PIN_PWDN    -1
#define CAM_PIN_RESET   -1
#define CAM_PIN_XCLK    10
#define CAM_PIN_SIOD    40
#define CAM_PIN_SIOC    39
#define CAM_PIN_D7      48
#define CAM_PIN_D6      11
#define CAM_PIN_D5      12
#define CAM_PIN_D4      14
#define CAM_PIN_D3      16
#define CAM_PIN_D2      18
#define CAM_PIN_D1      17
#define CAM_PIN_D0      15
#define CAM_PIN_VSYNC   38
#define CAM_PIN_HREF    47
#define CAM_PIN_PCLK    13

static camera_fb_t* _fb = nullptr;

namespace Camera {

bool init() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = CAM_PIN_D0;
  config.pin_d1       = CAM_PIN_D1;
  config.pin_d2       = CAM_PIN_D2;
  config.pin_d3       = CAM_PIN_D3;
  config.pin_d4       = CAM_PIN_D4;
  config.pin_d5       = CAM_PIN_D5;
  config.pin_d6       = CAM_PIN_D6;
  config.pin_d7       = CAM_PIN_D7;
  config.pin_xclk     = CAM_PIN_XCLK;
  config.pin_pclk     = CAM_PIN_PCLK;
  config.pin_vsync    = CAM_PIN_VSYNC;
  config.pin_href     = CAM_PIN_HREF;
  config.pin_sscb_sda = CAM_PIN_SIOD;
  config.pin_sscb_scl = CAM_PIN_SIOC;
  config.pin_pwdn     = CAM_PIN_PWDN;
  config.pin_reset    = CAM_PIN_RESET;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size   = CAM_FRAME_SIZE;
  config.jpeg_quality = CAM_JPEG_QUALITY;
  config.fb_count     = 1;
  config.grab_mode    = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location  = CAMERA_FB_IN_PSRAM;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    DBG("Camera init failed: 0x%x\n", err);
    return false;
  }

  // Warm-up: discard first N frames (sensor auto-exposure needs time)
  for (int i = 0; i < WARMUP_FRAMES; i++) {
    camera_fb_t* warmup = esp_camera_fb_get();
    if (warmup) esp_camera_fb_return(warmup);
    delay(100);
  }

  DBG("Camera initialized (QVGA JPEG q=%d)\n", CAM_JPEG_QUALITY);
  return true;
}

bool captureJpeg(uint8_t** outBuf, size_t* outLen) {
  if (_fb) {
    esp_camera_fb_return(_fb);
    _fb = nullptr;
  }

  _fb = esp_camera_fb_get();
  if (!_fb) {
    DBG("Camera capture failed\n");
    return false;
  }

  *outBuf = _fb->buf;
  *outLen = _fb->len;
  DBG("Captured JPEG: %u bytes\n", _fb->len);
  return true;
}

void releaseFrame() {
  if (_fb) {
    esp_camera_fb_return(_fb);
    _fb = nullptr;
  }
}

} // namespace Camera
