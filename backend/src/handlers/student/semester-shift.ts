/**
 * POST /students/semester-shift — Cognito authorized
 *
 * Bulk promote or demote students by semester.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, extractUser, getItem, updateItem, logAction } from '../../lib';
import { TABLE_NAMES, SEMESTER_ORDER, SEMESTER_DEMOTION } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Student } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const { studentIds, action } = JSON.parse(event.body ?? '{}');

    if (!Array.isArray(studentIds) || studentIds.length === 0) {
      return respond.badRequest('studentIds array is required');
    }
    if (action !== 'promote' && action !== 'demote') {
      return respond.badRequest('action must be "promote" or "demote"');
    }

    const map = action === 'promote' ? SEMESTER_ORDER : SEMESTER_DEMOTION;
    const now = getISTTimestamp();
    const results: { studentId: string; from: string; to: string | null }[] = [];
    const errors: { studentId: string; reason: string }[] = [];

    for (const id of studentIds) {
      const student = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId: id });
      if (!student) {
        errors.push({ studentId: id, reason: 'Not found' });
        continue;
      }

      const newSem = map[student.semester];
      if (!newSem) {
        errors.push({ studentId: id, reason: `Cannot ${action} from ${student.semester}` });
        continue;
      }

      await updateItem({
        tableName: TABLE_NAMES.STUDENTS,
        key: { studentId: id },
        updateExpression: 'SET semester = :s, updatedAt = :u',
        expressionValues: { ':s': newSem, ':u': now },
      });

      results.push({ studentId: id, from: student.semester, to: newSem });
    }

    await logAction({
      actorId: user.userId,
      action: `SEMESTER_${action.toUpperCase()}`,
      targetEntity: 'student',
      targetId: `${results.length} students`,
    });

    return respond.ok({ shifted: results, errors, count: results.length });
  } catch (err: any) {
    console.error('[STUDENT/SEMESTER-SHIFT]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to shift semesters');
  }
};
