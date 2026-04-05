/**
 * Marrty IFR31 — Core Data Models
 *
 * All entity interfaces used across Lambda handlers.
 * Keep in sync with DynamoDB table schemas defined in CDK.
 */

// ─── Student ───────────────────────────────────────────────

export type StudentStatus = 'active' | 'inactive' | 'passout';
export type Semester = 'S3' | 'S4' | 'S5' | 'S6';
export type Gender = 'Male' | 'Female' | 'Other';

export interface Student {
  studentId: string;
  name: string;
  rollNo: string;
  pnr: string;
  batchYear: string;
  semester: Semester;
  gender: Gender;
  dob: string;
  phone: string;
  email: string;
  status: StudentStatus;
  profilePhotoKey?: string;
  faceIds: string[];
  createdAt: string;
  updatedAt: string;
}

// ─── Faculty ───────────────────────────────────────────────

export type FacultyStatus = 'active' | 'inactive';

export interface Faculty {
  facultyId: string;
  name: string;
  systemId: string;
  gender: Gender;
  email: string;
  phone: string;
  status: FacultyStatus;
  profilePhotoKey?: string;
  faceIds: string[];
  createdAt: string;
  updatedAt: string;
}

// ─── Attendance ────────────────────────────────────────────

export type SessionType = 'Morning' | 'Interval' | 'Afternoon' | 'Evening';
export type AttendanceMethod = 'auto' | 'auto-mobile' | 'manual';
export type AttendanceStatus = 'Present' | 'Late' | 'Already Marked' | 'Unknown';
export type Emotion = 'HAPPY' | 'CALM' | 'SAD' | 'SURPRISED' | 'ANGRY' | 'CONFUSED' | 'DISGUSTED' | 'FEAR';

export interface AttendanceRecord {
  recordId: string;
  studentId: string;
  sessionType: SessionType;
  date: string;        // YYYY-MM-DD (IST)
  time: string;        // HH:mm:ss (IST)
  method: AttendanceMethod;
  markedBy?: string;   // userId of faculty (for manual/mobile)
  deviceId?: string;   // device ID (for auto)
  confidence?: number; // Rekognition confidence score
  scanImageKey?: string;
  emotion?: Emotion;
  emotionConfidence?: number;
  streak?: number;
  latitude?: number;   // GPS (mobile scan only)
  longitude?: number;  // GPS (mobile scan only)
  createdAt: string;
}

// ─── Session Config ────────────────────────────────────────

export interface SessionConfig {
  sessionId: string;
  name: SessionType;
  startTime: string;   // HH:mm (IST)
  endTime: string;     // HH:mm (IST)
  isActive: boolean;
  updatedAt: string;
}

// ─── Audit Log ─────────────────────────────────────────────

export interface AuditLog {
  logId: string;
  actorId: string;
  action: string;
  targetEntity: string;
  targetId: string;
  ipAddress?: string;
  latitude?: number;
  longitude?: number;
  timestamp: string;
}

// ─── Bug Report ────────────────────────────────────────────

export type BugReportType = 'bug' | 'technical' | 'feature' | 'other';
export type BugReportStatus = 'Open' | 'In Review' | 'Resolved';

export interface BugReport {
  reportId: string;
  reporterId: string;
  type: BugReportType;
  description: string;
  status: BugReportStatus;
  createdAt: string;
  updatedAt: string;
}

// ─── Auth / User Context ───────────────────────────────────

export type UserRole = 'hod' | 'lecturer';

export interface UserContext {
  userId: string;
  email: string;
  role: UserRole;
  groups: string[];
}

// ─── API Response Types ────────────────────────────────────

export interface FaceSearchResult {
  matched: boolean;
  entityType?: 'student' | 'faculty';
  entityId?: string;
  name?: string;
  confidence?: number;
  emotion?: Emotion;
  emotionConfidence?: number;
  reason?: string;
}

export interface AttendanceMarkResult {
  status: 'Present' | 'Late' | 'Already Marked' | 'Unknown' | 'Spoofing' | 'OutOfZone' | 'Error';
  studentName?: string;
  sessionName?: string;
  date?: string;
  time?: string;
  streak?: number;
  emotion?: Emotion;
  message?: string;
}
