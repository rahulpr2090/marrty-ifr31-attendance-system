/**
 * Zod Validation Schemas
 *
 * Input validation for all API endpoints. Rejects bad data before
 * it reaches DynamoDB. Used in handler functions.
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

import { z } from 'zod';

// ─── Shared Enums ──────────────────────────────────────────

const semesters = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6'] as const;
const genders = ['Male', 'Female', 'Other'] as const;
const batchYears = ['2022-25', '2023-26', '2024-27', '2025-28', '2026-29', '2027-30'] as const;
const sessionTypes = ['Morning', 'Interval', 'Afternoon', 'Evening'] as const;
const bugTypes = ['bug', 'technical', 'feature', 'other'] as const;
const bugStatuses = ['Open', 'In Review', 'Resolved'] as const;

// ─── Student ───────────────────────────────────────────────

export const createStudentSchema = z.object({
  name: z.string().min(2).max(100).trim(),
  rollNo: z.string().min(1).max(20).trim(),
  pnr: z.string().min(1).max(20).trim(),
  batchYear: z.enum(batchYears),
  semester: z.enum(semesters),
  gender: z.enum(genders),
  dob: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date format: YYYY-MM-DD').optional(),
  phone: z.string().regex(/^\d{10}$/, 'Phone must be 10 digits'),
  email: z.string().email().max(100).trim().toLowerCase(),
});

export const updateStudentSchema = createStudentSchema.partial();

// ─── Faculty ───────────────────────────────────────────────

export const createFacultySchema = z.object({
  name: z.string().min(2).max(100).trim(),
  gender: z.enum(genders),
  email: z.string().email().max(100).trim().toLowerCase(),
  phone: z.string().regex(/^\d{10}$/, 'Phone must be 10 digits'),
});

export const updateFacultySchema = createFacultySchema.partial();

// ─── Attendance ────────────────────────────────────────────

export const manualAttendanceSchema = z.object({
  studentIds: z.array(z.string().uuid()).min(1).max(100),
  sessionType: z.enum(sessionTypes),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  reason: z.string().min(5).max(500).trim(),
  status: z.string().optional(),
});

export const markAttendanceSchema = z.object({
  image: z.string().min(100),  // Base64 encoded image
  deviceId: z.string().min(1),
});

export const markMobileAttendanceSchema = z.object({
  image: z.string().min(100),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

// ─── Session Config ────────────────────────────────────────

export const updateSessionSchema = z.object({
  startTime: z.string().regex(/^\d{2}:\d{2}$/, 'Format: HH:mm'),
  endTime: z.string().regex(/^\d{2}:\d{2}$/, 'Format: HH:mm'),
});

// ─── Bug Report ────────────────────────────────────────────

export const createBugReportSchema = z.object({
  type: z.enum(bugTypes),
  description: z.string().min(10).max(2000).trim(),
});

export const updateBugStatusSchema = z.object({
  status: z.enum(bugStatuses),
});

// ─── Sub-Admin ─────────────────────────────────────────────

export const createSubAdminSchema = z.object({
  email: z.string().email().trim().toLowerCase(),
  name: z.string().min(2).max(100).trim(),
  permissions: z.object({
    batches: z.array(z.enum(batchYears)),
    semesters: z.array(z.enum(semesters)),
    canMarkAttendance: z.boolean(),
    canManageStudents: z.boolean(),
  }),
});

// ─── Geofence ──────────────────────────────────────────────

export const updateGeofenceSchema = z.union([
  z.object({
    polygon: z.array(z.tuple([z.number(), z.number()])).min(3).max(10),
  }),
  z.object({
    center: z.object({ lat: z.number(), lng: z.number() }),
    radiusMeters: z.number().min(50).max(500),
  }),
]);

// ─── Report ────────────────────────────────────────────────

export const generateReportSchema = z.object({
  type: z.enum(['excel', 'pdf']),
  dateFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  dateTo: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  batchYear: z.enum(batchYears).optional(),
  semester: z.enum(semesters).optional(),
  studentId: z.string().uuid().optional(),
});
