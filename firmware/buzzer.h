/**
 * buzzer.h — Context-aware buzzer tones
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

namespace Buzzer {

void init();

// Auto-adjusts volume based on IST time of day
uint8_t getTimeBasedVolume();

void scanBeep();          // Single click
void successBeep();       // Two ascending musical beeps
void errorBeep();         // One long low beep
void alreadyMarkedBeep(); // Three quick beeps
void spoofBeep();         // Rapid warning pattern

} // namespace Buzzer
