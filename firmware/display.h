/**
 * display.h — TFT Display Driver (ST7735 128×160)
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

namespace Display {

void init();

// ── Idle / Status ──────────────────────────────────
void showIdle(const char* sessionName, const char* timeStr);
void updateIdleClock(const char* timeStr);
void showWifiConnecting();
void showOffline(int queueCount);

// ── Scan States ────────────────────────────────────
void showScanning();
void showProcessing();

// ── Results ────────────────────────────────────────
void showSuccess(const char* name, const char* session,
                 const char* date, const char* timeStr,
                 int streak, const char* emotion);
void showAlreadyMarked(const char* name);
void showUnknown();
void showSpoofing();
void showError(const char* msg);

} // namespace Display
