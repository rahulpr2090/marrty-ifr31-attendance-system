/**
 * Application Constants
 *
 * Table names read from environment variables (set by CDK).
 * Domain constants used across handlers.
 */

// ─── DynamoDB Table Names (from env vars) ──────────────────

export const TABLE_NAMES = {
  STUDENTS: process.env.STUDENTS_TABLE ?? 'marrty-students',
  FACULTY: process.env.FACULTY_TABLE ?? 'marrty-faculty',
  ATTENDANCE: process.env.ATTENDANCE_TABLE ?? 'marrty-attendance',
  SESSIONS: process.env.SESSIONS_TABLE ?? 'marrty-sessions',
  AUDIT: process.env.AUDIT_TABLE ?? 'marrty-audit',
  BUGS: process.env.BUGS_TABLE ?? 'marrty-bugs',
} as const;

// ─── S3 Bucket Names (from env vars) ──────────────────────

export const BUCKET_NAMES = {
  FACE_IMAGES: process.env.FACE_IMAGES_BUCKET ?? 'marrty-face-images',
  SCAN_IMAGES: process.env.SCAN_IMAGES_BUCKET ?? 'marrty-scan-images',
  PROFILES: process.env.PROFILES_BUCKET ?? 'marrty-profiles',
  EXPORTS: process.env.EXPORTS_BUCKET ?? 'marrty-exports',
} as const;

// ─── AWS Resource IDs (from env vars) ─────────────────────

export const AWS_CONFIG = {
  USER_POOL_ID: process.env.USER_POOL_ID ?? '',
  CLIENT_ID: process.env.CLIENT_ID ?? '',
  COLLECTION_ID: process.env.COLLECTION_ID ?? 'marrty-faces',
  GEOFENCE_COLLECTION: process.env.GEOFENCE_COLLECTION ?? 'marrty-geofences',
  TRACKER_NAME: process.env.TRACKER_NAME ?? 'marrty-tracker',
} as const;

// ─── Domain Constants ─────────────────────────────────────

export const BATCH_YEARS = ['2023-26', '2024-27', '2025-28', '2026-29', '2027-30'] as const;
export const SEMESTERS = ['S3', 'S4', 'S5', 'S6'] as const;
export const SESSION_TYPES = ['Morning', 'Interval', 'Afternoon', 'Evening'] as const;
export const STUDENT_STATUSES = ['active', 'inactive', 'passout'] as const;

// ─── Limits ───────────────────────────────────────────────

export const LIMITS = {
  MAX_FACE_IMAGES: 3,
  MAX_IMAGE_SIZE_MB: 20,
  MAX_OFFLINE_QUEUE: 30,
  DEFAULT_PAGE_SIZE: 25,
  MAX_PAGE_SIZE: 100,
  FACE_CONFIDENCE_THRESHOLD: 90,
  DEFAULT_ATTENDANCE_THRESHOLD: 75,
  SCAN_IMAGE_RETENTION_DAYS: 180,
  EXPORT_RETENTION_DAYS: 30,
} as const;

// ─── Semester Promotion Map ───────────────────────────────

export const SEMESTER_ORDER: Record<string, string | null> = {
  S3: 'S4',
  S4: 'S5',
  S5: 'S6',
  S6: null, // After S6 → passout
};

export const SEMESTER_DEMOTION: Record<string, string | null> = {
  S6: 'S5',
  S5: 'S4',
  S4: 'S3',
  S3: null,
};
