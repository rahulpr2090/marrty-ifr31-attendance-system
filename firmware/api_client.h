/**
 * api_client.h — REST API client for attendance marking
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

#pragma once
#include <Arduino.h>

struct AttendanceResult {
  String status;       // "Present", "Late", "Already Marked", "Spoofing", "Unknown", "Error"
  String studentName;
  String sessionName;
  String date;
  String time;
  String emotion;
  int    streak;
  bool   success;
  String errorMsg;
};

namespace ApiClient {
  AttendanceResult markAttendance(const uint8_t* jpegData, size_t jpegSize);
}
