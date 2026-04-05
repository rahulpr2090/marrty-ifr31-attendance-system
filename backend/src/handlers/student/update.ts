/**
 * PUT /students/{studentId} — Cognito authorized
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, extractUser, getItem, queryItems, updateItem, logAction } from '../../lib';
import { updateStudentSchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Student } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return respond.badRequest('studentId is required');

    const parsed = updateStudentSchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) return respond.badRequest('Validation failed', parsed.error.flatten());

    const existing = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId });
    if (!existing) return respond.notFound('Student not found');

    const data = parsed.data;

    // Check duplicate rollNo if changed
    if (data.rollNo && data.rollNo !== existing.rollNo) {
      const { items } = await queryItems({
        tableName: TABLE_NAMES.STUDENTS,
        indexName: 'rollNo-index',
        keyCondition: 'rollNo = :r',
        expressionValues: { ':r': data.rollNo },
        limit: 1,
      });
      if (items.length > 0) return respond.conflict(`Roll No ${data.rollNo} already exists`);
    }

    // Check duplicate pnr if changed
    if (data.pnr && data.pnr !== existing.pnr) {
      const { items } = await queryItems({
        tableName: TABLE_NAMES.STUDENTS,
        indexName: 'pnr-index',
        keyCondition: 'pnr = :p',
        expressionValues: { ':p': data.pnr },
        limit: 1,
      });
      if (items.length > 0) return respond.conflict(`PNR ${data.pnr} already exists`);
    }

    // Build update expression dynamically
    const fields = Object.entries(data);
    if (fields.length === 0) return respond.badRequest('No fields to update');

    const expParts: string[] = ['updatedAt = :u'];
    const expValues: Record<string, unknown> = { ':u': getISTTimestamp() };
    const expNames: Record<string, string> = {};

    for (const [key, val] of fields) {
      const placeholder = `:${key}`;
      const nameKey = `#${key}`;
      expParts.push(`${nameKey} = ${placeholder}`);
      expValues[placeholder] = val;
      expNames[nameKey] = key;
    }

    await updateItem({
      tableName: TABLE_NAMES.STUDENTS,
      key: { studentId },
      updateExpression: `SET ${expParts.join(', ')}`,
      expressionValues: expValues,
      expressionNames: expNames,
    });

    await logAction({
      actorId: user.userId,
      action: 'UPDATE_STUDENT',
      targetEntity: 'student',
      targetId: studentId,
    });

    return respond.ok({ studentId, updated: Object.keys(data), message: 'Student updated' });
  } catch (err: any) {
    console.error('[STUDENT/UPDATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to update student');
  }
};
