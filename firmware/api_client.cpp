/**
 * api_client.cpp — HTTPS REST client using HTTPClient + WiFiClientSecure
 *
 * Encodes JPEG as base64, POSTs to /attendance/mark, parses JSON response.
 * Uses mbedtls_base64_encode (built-in ESP32 crypto library).
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#include "api_client.h"
#include "config.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include "mbedtls/base64.h"

// ── Base64 encode ────────────────────────────────────
static String base64Encode(const uint8_t* data, size_t len) {
  size_t outLen = 0;
  // Calculate required output length
  mbedtls_base64_encode(nullptr, 0, &outLen, data, len);
  String out;
  out.reserve(outLen);
  uint8_t* buf = (uint8_t*)malloc(outLen);
  if (!buf) return "";
  mbedtls_base64_encode(buf, outLen, &outLen, data, len);
  out = String((char*)buf).substring(0, outLen);
  free(buf);
  return out;
}

namespace ApiClient {

AttendanceResult markAttendance(const uint8_t* jpegData, size_t jpegSize) {
  AttendanceResult result;
  result.success = false;
  result.streak  = 0;

  // ── Encode image ─────────────────────────────────
  DBG("Encoding %u bytes as base64...\n", jpegSize);
  String b64 = base64Encode(jpegData, jpegSize);
  if (b64.isEmpty()) {
    result.errorMsg = "Base64 encode failed";
    return result;
  }
  DBG("Encoded: %u chars\n", b64.length());

  // ── Build JSON body ───────────────────────────────
  String url = String(API_BASE_URL) + "/attendance/mark";
  DBG("POST %s\n", url.c_str());

  // Build JSON manually to avoid large DynamicJsonDocument on heap
  String body = "{\"image\":\"" + b64 + "\",\"deviceId\":\"" DEVICE_ID "\"}";

  // ── HTTP request ──────────────────────────────────
  WiFiClientSecure client;
  client.setInsecure(); // Skip certificate verification (dev mode)
  // For production: client.setCACert(rootCACert);

  HTTPClient http;
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-api-key", API_KEY);
  http.setTimeout(API_TIMEOUT_MS);

  int httpCode = http.POST(body);
  DBG("HTTP response code: %d\n", httpCode);

  if (httpCode <= 0) {
    result.errorMsg = "Network error (" + String(httpCode) + ")";
    http.end();
    return result;
  }

  if (httpCode != 200) {
    result.errorMsg = "HTTP " + String(httpCode);
    http.end();
    return result;
  }

  // ── Parse JSON response ───────────────────────────
  String payload = http.getString();
  http.end();
  DBG("Response: %s\n", payload.c_str());

  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    result.errorMsg = "JSON parse failed";
    return result;
  }

  result.status      = doc["status"]      | "Error";
  result.studentName = doc["studentName"] | "";
  result.sessionName = doc["sessionName"] | "";
  result.date        = doc["date"]        | "";
  result.time        = doc["time"]        | "";
  result.emotion     = doc["emotion"]     | "";
  result.streak      = doc["streak"]      | 0;
  result.success     = true;

  return result;
}

} // namespace ApiClient
