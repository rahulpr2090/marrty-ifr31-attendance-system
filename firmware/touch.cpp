/**
 * touch.cpp — Capacitive touch with INPUT_PULLDOWN + rising edge detection
 *
 * Uses INPUT_PULLDOWN to prevent floating pin false triggers.
 * Debounced with TOUCH_DEBOUNCE_MS to prevent rapid re-triggering.
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "touch.h"
#include "config.h"

static bool _lastState = false;
static unsigned long _lastTriggerMs = 0;

namespace Touch {

void init() {
  pinMode(TOUCH_PIN, INPUT_PULLDOWN);
  DBG("Touch initialized (GPIO %d, PULLDOWN)\n", TOUCH_PIN);
}

// Returns true once per press (rising edge, debounced)
bool isTouched() {
  bool current = (digitalRead(TOUCH_PIN) == HIGH);

  // Rising edge: LOW → HIGH
  if (current && !_lastState) {
    unsigned long now = millis();
    if (now - _lastTriggerMs > TOUCH_DEBOUNCE_MS) {
      _lastTriggerMs = now;
      _lastState = true;
      return true;
    }
  }

  if (!current) {
    _lastState = false;
  }

  return false;
}

} // namespace Touch
