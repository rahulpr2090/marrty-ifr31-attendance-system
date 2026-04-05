// lib/core/constants/api_constants.dart
// API endpoint paths and timeouts.
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

class ApiConstants {
  ApiConstants._();

  // ── Replace with your CDK deployment output URL ─────
  // After running `cdk deploy`, paste the ApiUrl output below.
  // Example: https://abc123xyz.execute-api.ap-south-1.amazonaws.com/api
  static const baseUrl = 'https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/api';

  // ── Auth ─────────────────────────────────────────────
  static const login          = '/auth/login';
  static const verifyMfa      = '/auth/verify-mfa';
  static const changePassword = '/auth/change-password';
  static const me             = '/auth/me';
  static const subAdmins      = '/auth/sub-admins';

  // ── Session ──────────────────────────────────────────
  static const sessions       = '/sessions';
  static const activeSession  = '/sessions/active';

  // ── Students ─────────────────────────────────────────
  static const students       = '/students';
  static const semesterShift  = '/students/semester-shift';
  static const markPassout    = '/students/mark-passout';
  static const bulkImport     = '/students/bulk-import';

  // ── Faculty ──────────────────────────────────────────
  static const faculty        = '/faculty';

  // ── Face ─────────────────────────────────────────────
  static const faceEnroll     = '/face/enroll';
  static const faceSearch     = '/face/search';

  // ── Attendance ───────────────────────────────────────
  static const attendanceMark       = '/attendance/mark';
  static const attendanceMarkMobile = '/attendance/mark-mobile';
  static const attendanceManual     = '/attendance/manual';
  static const attendanceRecords    = '/attendance/records';
  static const attendanceToday      = '/attendance/today';
  static const attendanceDefaulters = '/attendance/defaulters';
  static const attendanceStreaks    = '/attendance/streaks';
  static const attendanceAnomalies  = '/attendance/anomalies';
  static const attendanceDigest     = '/attendance/digest';

  // ── Geofence ─────────────────────────────────────────
  static const geofence       = '/geofence';
  static const geofenceCheck  = '/geofence/check';

  // ── Reports ──────────────────────────────────────────
  static const reportsGenerate = '/reports/generate';
  static const reportsShare    = '/reports/share';

  // ── Audit ────────────────────────────────────────────
  static const auditLogs      = '/audit/logs';

  // ── Bugs ─────────────────────────────────────────────
  static const bugs           = '/bugs';

  // ── Timeouts ────────────────────────────────────────
  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 30);
}
