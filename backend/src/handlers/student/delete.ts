/**
 * DELETE /students/{studentId} — Soft delete (status → inactive)
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, extractUser, getItem, updateItem, logAction } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Student } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return respond.badRequest('studentId is required');

    const existing = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId });
    if (!existing) return respond.notFound('Student not found');

    await updateItem({
      tableName: TABLE_NAMES.STUDENTS,
      key: { studentId },
      updateExpression: 'SET #st = :s, updatedAt = :u',
      expressionValues: { ':s': 'inactive', ':u': getISTTimestamp() },
      expressionNames: { '#st': 'status' },
    });

    await logAction({
      actorId: user.userId,
      action: 'DELETE_STUDENT',
      targetEntity: 'student',
      targetId: studentId,
    });

    return respond.ok({ studentId, message: 'Student deactivated' });
  } catch (err: any) {
    console.error('[STUDENT/DELETE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to delete student');
  }
};
