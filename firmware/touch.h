/**
 * touch.h — Capacitive touch sensor with debounce
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

namespace Touch {
  void init();
  bool isTouched(); // True on rising edge (debounced)
}
