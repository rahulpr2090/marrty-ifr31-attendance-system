/**
 * state_machine.h — Main firmware state machine
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

enum class State {
  INIT,
  IDLE,
  CAPTURE,
  UPLOAD,
  RESULT,
  ERROR_STATE
};

namespace StateMachine {
  void begin();
  void run();        // Call in loop() — non-blocking state machine tick
  State getState();  // For diagnostics
}
