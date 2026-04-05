/**
 * display.cpp — TFT Display Driver (ST7735 128×160, Hardware SPI)
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 *
 * Libraries: Adafruit_GFX, Adafruit_ST7735
 */

#include "display.h"
#include "config.h"
#include <Adafruit_GFX.h>
#include <Adafruit_ST7735.h>
#include <SPI.h>

// ── Colors ──────────────────────────────────────────
#define COLOR_BG       0x0000  // Black
#define COLOR_TEXT     0xFFFF  // White
#define COLOR_GREEN    0x07E0  // Pure green
#define COLOR_DKGREEN  0x03E0  // Dark green
#define COLOR_RED      0xF800  // Red
#define COLOR_ORANGE   0xFD00  // Orange
#define COLOR_AMBER    0xFEA0  // Amber/yellow
#define COLOR_GRAY     0x7BEF  // Gray
#define COLOR_LTGRAY   0xC618  // Light gray
#define COLOR_CYAN     0x07FF  // Cyan (emotion: calm)
#define COLOR_HEADER   0x2945  // Dark navy header

static Adafruit_ST7735 tft = Adafruit_ST7735(TFT_CS, TFT_DC, TFT_RST);

// ── Internal helpers ────────────────────────────────

static void fillBg(uint16_t color) {
  tft.fillScreen(color);
}

// Draw centered text — clears previous content on that line width first
static void drawCentered(const char* text, int16_t y, uint8_t size, uint16_t color,
                          uint16_t bgColor = COLOR_BG) {
  tft.setTextSize(size);
  tft.setTextColor(color, bgColor);
  int16_t x1, y1;
  uint16_t w, h;
  tft.getTextBounds(text, 0, y, &x1, &y1, &w, &h);
  int16_t x = (TFT_WIDTH - w) / 2;
  if (x < 0) x = 0;
  tft.setCursor(x, y);
  // Clear the row background first to avoid ghosting
  tft.fillRect(0, y - 1, TFT_WIDTH, h + 3, bgColor);
  tft.print(text);
}

static void drawHeader(const char* title, uint16_t bgColor = COLOR_HEADER) {
  tft.fillRect(0, 0, TFT_WIDTH, 20, bgColor);
  tft.setTextSize(1);
  tft.setTextColor(COLOR_TEXT, bgColor);
  int16_t x1, y1; uint16_t w, h;
  tft.getTextBounds(title, 0, 6, &x1, &y1, &w, &h);
  tft.setCursor((TFT_WIDTH - w) / 2, 6);
  tft.print(title);
}

static void drawFooter(const char* text, uint16_t bgColor = COLOR_HEADER) {
  tft.fillRect(0, TFT_HEIGHT - 16, TFT_WIDTH, 16, bgColor);
  tft.setTextSize(1);
  tft.setTextColor(COLOR_GRAY, bgColor);
  int16_t x1, y1; uint16_t w, h;
  tft.getTextBounds(text, 0, TFT_HEIGHT - 11, &x1, &y1, &w, &h);
  tft.setCursor((TFT_WIDTH - w) / 2, TFT_HEIGHT - 11);
  tft.print(text);
}

// Determine greeting and emotion emoji based on hour and emotion string
static const char* getGreeting(const char* name, int hour, char* out, size_t outLen) {
  const char* prefix;
  const char* suffix;
  if (hour < 10) {
    prefix = "Good Morning";
    suffix = "!";
  } else if (hour < 14) {
    prefix = "Hey";
    suffix = "!";
  } else {
    prefix = "Good Afternoon";
    suffix = "!";
  }
  snprintf(out, outLen, "%s %s%s", prefix, name, suffix);
  return out;
}

static const char* emotionEmoji(const char* emotion) {
  if (!emotion) return "";
  if (strncmp(emotion, "HAPPY", 5) == 0)     return ":-D";
  if (strncmp(emotion, "CALM", 4) == 0)       return ":-)";
  if (strncmp(emotion, "SAD", 3) == 0)        return ":-(";
  if (strncmp(emotion, "SURPRISED", 9) == 0)  return ":-O";
  if (strncmp(emotion, "ANGRY", 5) == 0)      return ":-<";
  return "";
}

// ── Public functions ────────────────────────────────

namespace Display {

void init() {
  tft.initR(INITR_BLACKTAB); // INITR_BLACKTAB for common ST7735 modules
  tft.setRotation(0);        // Portrait
  tft.fillScreen(COLOR_BG);
  DBG("Display initialized\n");
}

void showIdle(const char* sessionName, const char* timeStr) {
  fillBg(COLOR_BG);

  // Header — CSE DEPT
  drawHeader("HGPC - CSE DEPT");

  // Logo / branding line
  tft.fillRect(0, 22, TFT_WIDTH, 1, COLOR_DKGREEN);

  // Time — large, centred
  tft.setTextSize(3);
  tft.setTextColor(COLOR_TEXT, COLOR_BG);
  int16_t x1, y1; uint16_t w, h;
  tft.getTextBounds(timeStr, 0, 32, &x1, &y1, &w, &h);
  tft.fillRect(0, 30, TFT_WIDTH, 26, COLOR_BG);
  tft.setCursor((TFT_WIDTH - w) / 2, 32);
  tft.print(timeStr);

  // Session name
  drawCentered(sessionName, 62, 1, COLOR_GREEN);

  // Divider
  tft.fillRect(10, 78, TFT_WIDTH - 20, 1, COLOR_GRAY);

  // Touch prompt
  drawCentered("Touch to Scan", 88, 1, COLOR_LTGRAY);

  // WiFi indicator (top right, small dot)
  tft.fillCircle(TFT_WIDTH - 8, 10, 4, COLOR_GREEN);

  // Footer
  drawFooter("Marrty IFR31 v" FIRMWARE_VERSION);
}

void updateIdleClock(const char* timeStr) {
  // Only refresh the clock area — avoids full redraw flicker
  tft.fillRect(0, 30, TFT_WIDTH, 26, COLOR_BG);
  tft.setTextSize(3);
  tft.setTextColor(COLOR_TEXT, COLOR_BG);
  int16_t x1, y1; uint16_t w, h;
  tft.getTextBounds(timeStr, 0, 32, &x1, &y1, &w, &h);
  tft.setCursor((TFT_WIDTH - w) / 2, 32);
  tft.print(timeStr);
}

void showWifiConnecting() {
  fillBg(COLOR_BG);
  drawHeader("Connecting...");

  drawCentered("((( WiFi )))", 55, 2, COLOR_CYAN);
  drawCentered("Please wait...", 85, 1, COLOR_GRAY);

  tft.setTextSize(1);
  tft.setTextColor(COLOR_GRAY, COLOR_BG);
  tft.setCursor(4, TFT_HEIGHT - 12);
  tft.print(WIFI_SSID);
}

void showOffline(int queueCount) {
  fillBg(0x3186); // Dark blue-gray
  drawHeader("OFFLINE");

  drawCentered("No WiFi", 50, 2, COLOR_AMBER);
  char buf[32];
  snprintf(buf, sizeof(buf), "Queued: %d scans", queueCount);
  drawCentered(buf, 82, 1, COLOR_LTGRAY);
  drawCentered("Touch to retry", 100, 1, COLOR_GRAY);
}

void showScanning() {
  fillBg(COLOR_BG);
  drawHeader("SCANNING");

  drawCentered("Please", 45, 2, COLOR_TEXT);
  drawCentered("hold still...", 68, 2, COLOR_TEXT);

  // Draw a simple face outline icon
  tft.drawCircle(TFT_WIDTH / 2, 110, 18, COLOR_GREEN);
  tft.fillCircle(TFT_WIDTH / 2 - 6, 107, 2, COLOR_GREEN);
  tft.fillCircle(TFT_WIDTH / 2 + 6, 107, 2, COLOR_GREEN);
  tft.drawArc(TFT_WIDTH / 2, 117, 8, 6, 200, 340, COLOR_GREEN);
}

void showProcessing() {
  fillBg(COLOR_BG);
  drawHeader("PROCESSING");
  drawCentered("Identifying...", 55, 1, COLOR_AMBER);
  drawCentered("Please wait", 72, 1, COLOR_GRAY);

  // Draw spinner segments
  int cx = TFT_WIDTH / 2, cy = 110;
  for (int i = 0; i < 8; i++) {
    float angle = i * 45.0f * PI / 180.0f;
    int x = cx + (int)(cos(angle) * 14);
    int y = cy + (int)(sin(angle) * 14);
    uint16_t c = (i < 6) ? COLOR_GREEN : COLOR_GRAY;
    tft.fillCircle(x, y, 3, c);
  }
}

void showSuccess(const char* name, const char* session,
                 const char* date, const char* timeStr,
                 int streak, const char* emotion) {
  fillBg(COLOR_DKGREEN);
  tft.fillRect(0, 0, TFT_WIDTH, TFT_HEIGHT, 0x0640); // Deep green

  // ✓ checkmark box at top
  tft.fillRoundRect(54, 6, 20, 20, 4, COLOR_GREEN);
  tft.setTextSize(2);
  tft.setTextColor(COLOR_TEXT, COLOR_GREEN);
  tft.setCursor(59, 10);
  tft.print("v"); // Checkmark

  // Time-based greeting (use current IST hour from NTP)
  struct tm ti;
  getLocalTime(&ti);
  char greeting[40];
  getGreeting(name, ti.tm_hour, greeting, sizeof(greeting));

  tft.setTextSize(1);
  tft.setTextColor(COLOR_TEXT, 0x0640);
  // Truncate name if too long
  char nameLine[20];
  strncpy(nameLine, name, 14);
  nameLine[14] = '\0';
  drawCentered(nameLine, 30, 2, COLOR_TEXT, 0x0640);

  drawCentered("PRESENT", 54, 1, COLOR_GREEN, 0x0640);

  // Session + time
  char sessionLine[32];
  snprintf(sessionLine, sizeof(sessionLine), "%s | %s", session, timeStr);
  drawCentered(sessionLine, 68, 1, COLOR_LTGRAY, 0x0640);

  // Streak
  if (streak > 1) {
    char streakBuf[20];
    snprintf(streakBuf, sizeof(streakBuf), "Fire %d-day streak!", streak);
    drawCentered(streakBuf, 84, 1, COLOR_AMBER, 0x0640);
  }

  // Emotion
  const char* emo = emotionEmoji(emotion);
  if (strlen(emo) > 0) {
    char emoBuf[24];
    snprintf(emoBuf, sizeof(emoBuf), "Mood: %s", emo);
    drawCentered(emoBuf, 100, 1, COLOR_CYAN, 0x0640);
  }

  drawFooter("See you soon!", 0x0640);
}

void showAlreadyMarked(const char* name) {
  fillBg(0xFD00); // Orange
  drawHeader("ALREADY MARKED");

  char nameLine[16];
  strncpy(nameLine, name, 14);
  nameLine[14] = '\0';
  drawCentered(nameLine, 45, 2, COLOR_TEXT, 0xFD00);
  drawCentered("Already", 72, 2, COLOR_TEXT, 0xFD00);
  drawCentered("Marked [v]", 92, 1, COLOR_TEXT, 0xFD00);
}

void showUnknown() {
  fillBg(COLOR_RED);
  drawHeader("UNKNOWN FACE");

  drawCentered("?", 40, 6, COLOR_TEXT, COLOR_RED);
  drawCentered("Not recognized", 100, 1, COLOR_TEXT, COLOR_RED);
  drawCentered("Please enroll first", 114, 1, COLOR_TEXT, COLOR_RED);
}

void showSpoofing() {
  fillBg(0xA000); // Dark red
  drawHeader("!! ALERT !!");

  // Warning stripes
  for (int y = 22; y < TFT_HEIGHT - 16; y += 8) {
    tft.fillRect(0, y, TFT_WIDTH, 4, 0xA000);
    tft.fillRect(0, y + 4, TFT_WIDTH, 4, 0xC000);
  }

  drawCentered("[!] Spoofing", 35, 1, COLOR_AMBER, 0xA000);
  drawCentered("Detected!", 48, 2, COLOR_TEXT, 0xA000);
  drawCentered("Use your real face!", 85, 1, COLOR_TEXT, 0xA000);
  drawCentered("Photo rejected", 100, 1, COLOR_LTGRAY, 0xA000);
}

void showError(const char* msg) {
  fillBg(0x6000); // Dark red-brown
  drawHeader("ERROR");

  drawCentered("Oops!", 40, 2, COLOR_AMBER, 0x6000);

  // Wrap message
  tft.setTextSize(1);
  tft.setTextColor(COLOR_TEXT, 0x6000);
  tft.setCursor(4, 68);
  tft.print(msg);

  drawFooter("Please try again");
}

} // namespace Display
