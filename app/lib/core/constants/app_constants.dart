// lib/core/constants/app_constants.dart
// Application-wide constants synced with backend validators.
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

class AppConstants {
  AppConstants._();

  static const appName    = 'Marrty IFR31';
  static const orgName    = 'Dept. of Computer Engineering';
  static const college    = 'HGPC';
  static const appVersion = '1.0.0';
  static const timezone   = 'Asia/Kolkata';

  // ── Session auto-logout ──────────────────────────────
  static const sessionDurationHours    = 12;
  static const sessionWarningMinutes   = 10; // warn at 11h 50m

  // ── Batch years (synced with backend validators) ─────
  static const batchYears = [
    '2022-25', '2023-26', '2024-27', '2025-28', '2026-29', '2027-30',
  ];

  // ── Semesters (synced with backend validators) ───────
  static const semesters = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6'];

  // ── Session types ────────────────────────────────────
  static const sessionTypes = ['Morning', 'Interval', 'Afternoon', 'Evening'];

  // ── Defaulter threshold default ──────────────────────
  static const defaulterThreshold = 75.0;

  // ── Face enrollment ──────────────────────────────────
  static const maxFaceImages      = 3;
  static const maxImageUploadMB   = 20;
  static const maxImageBytes      = 20 * 1024 * 1024; // 20 MB

  // ── Dashboard refresh ────────────────────────────────
  static const dashboardRefreshSec  = 30;
  static const geofenceCheckMinutes = 2;

  // ── User roles ───────────────────────────────────────
  static const roleHod      = 'hod';
  static const roleLecturer = 'lecturer';
}
