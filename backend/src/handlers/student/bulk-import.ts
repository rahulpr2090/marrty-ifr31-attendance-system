/**
 * POST /students/bulk-import — Cognito authorized
 *
 * Import students from CSV. Validates each row.
 * Expected CSV: name,rollNo,pnr,batchYear,semester,gender,dob,phone,email
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, extractUser, putItem, logAction } from '../../lib';
import { createStudentSchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const csvData = event.body ?? '';

    if (!csvData.trim()) return respond.badRequest('CSV data is required');

    // Parse CSV rows
    const lines = csvData.trim().split('\n');
    if (lines.length < 2) return respond.badRequest('CSV must have a header + at least 1 row');

    const headers = lines[0].split(',').map((h) => h.trim().toLowerCase());
    const now = getISTTimestamp();
    let successCount = 0;
    const errors: { row: number; reason: string }[] = [];

    for (let i = 1; i < lines.length; i++) {
      const values = lines[i].split(',').map((v) => v.trim());
      const rowObj: Record<string, string> = {};
      headers.forEach((h, idx) => {
        rowObj[h] = values[idx] ?? '';
      });

      // Validate row
      const parsed = createStudentSchema.safeParse(rowObj);
      if (!parsed.success) {
        const issues = parsed.error.issues.map((e) => `${e.path}: ${e.message}`).join('; ');
        errors.push({ row: i + 1, reason: issues });
        continue;
      }

      try {
        await putItem(TABLE_NAMES.STUDENTS, {
          studentId: uuid(),
          ...parsed.data,
          status: 'active',
          faceIds: [],
          createdAt: now,
          updatedAt: now,
        });
        successCount++;
      } catch (err) {
        errors.push({ row: i + 1, reason: 'Database write failed' });
      }
    }

    await logAction({
      actorId: user.userId,
      action: 'BULK_IMPORT_STUDENTS',
      targetEntity: 'student',
      targetId: `${successCount} imported`,
    });

    return respond.ok({ success: successCount, failed: errors.length, errors });
  } catch (err: any) {
    console.error('[STUDENT/BULK-IMPORT]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to import students');
  }
};
