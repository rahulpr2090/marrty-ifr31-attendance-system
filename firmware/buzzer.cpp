/**
 * buzzer.cpp — Context-aware buzzer tones using LEDC (Channel 2)
 *
 * IMPORTANT: Uses LEDC channel 2 to avoid conflict with OV2640 camera
 *            which occupies LEDC channels 0 and 1.
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "buzzer.h"
#include "config.h"
#include <time.h>

#define LEDC_CHANNEL  2
#define LEDC_TIMER    2
#define LEDC_RES      8   // 8-bit resolution (0–255)

namespace Buzzer {

static void tone(uint32_t freq, uint32_t durationMs, uint8_t volume) {
  if (freq == 0) {
    ledcWrite(LEDC_CHANNEL, 0);
    delay(durationMs);
    return;
  }
  ledcSetup(LEDC_CHANNEL, freq, LEDC_RES);
  ledcAttachPin(BUZZER_PIN, LEDC_CHANNEL);
  ledcWrite(LEDC_CHANNEL, volume);
  delay(durationMs);
  ledcWrite(LEDC_CHANNEL, 0);
}

void init() {
  ledcSetup(LEDC_CHANNEL, 1000, LEDC_RES);
  ledcAttachPin(BUZZER_PIN, LEDC_CHANNEL);
  ledcWrite(LEDC_CHANNEL, 0);
  DBG("Buzzer initialized (LEDC ch %d)\n", LEDC_CHANNEL);
}

// Volume based on IST hour:
//   before 9:00 → low (60)
//   9:00–16:00  → normal (140)
//   after 16:00 → slightly lower (100)
uint8_t getTimeBasedVolume() {
  struct tm ti;
  if (!getLocalTime(&ti)) return 100;
  int h = ti.tm_hour;
  if (h < 9)  return 60;
  if (h < 16) return 140;
  return 100;
}

// Single short click — triggered when touch detected
void scanBeep() {
  uint8_t vol = getTimeBasedVolume();
  tone(2000, 50, vol);
}

// Two ascending beeps — present / success
void successBeep() {
  uint8_t vol = getTimeBasedVolume();
  tone(1800, 100, vol);
  delay(40);
  tone(2400, 150, vol);
}

// One long low beep — error / unknown
void errorBeep() {
  uint8_t vol = getTimeBasedVolume();
  tone(600, 500, vol);
}

// Three quick pip-pip-pip — already marked
void alreadyMarkedBeep() {
  uint8_t vol = getTimeBasedVolume();
  for (int i = 0; i < 3; i++) {
    tone(1500, 60, vol);
    delay(50);
  }
}

// Rapid da-da-da-daaa — spoofing warning (distinct, alarming)
void spoofBeep() {
  uint8_t vol = getTimeBasedVolume();
  for (int i = 0; i < 4; i++) {
    tone(800, 80, vol);
    delay(40);
  }
  delay(100);
  tone(400, 400, vol);
}

} // namespace Buzzer
