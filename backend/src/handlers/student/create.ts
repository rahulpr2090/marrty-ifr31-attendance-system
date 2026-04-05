/**
 * POST /students — Cognito authorized
 *
 * Create a new student. Checks duplicate rollNo and pnr.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, extractUser, putItem, queryItems, logAction } from '../../lib';
import { createStudentSchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const parsed = createStudentSchema.safeParse(JSON.parse(event.body ?? '{}'));

    if (!parsed.success) {
      return respond.badRequest('Validation failed', parsed.error.flatten());
    }

    const data = parsed.data;

    // Check duplicate rollNo
    const { items: byRoll } = await queryItems({
      tableName: TABLE_NAMES.STUDENTS,
      indexName: 'rollNo-index',
      keyCondition: 'rollNo = :r',
      expressionValues: { ':r': data.rollNo },
      limit: 1,
    });
    if (byRoll.length > 0) return respond.conflict(`Roll No ${data.rollNo} already exists`);

    // Check duplicate pnr
    const { items: byPnr } = await queryItems({
      tableName: TABLE_NAMES.STUDENTS,
      indexName: 'pnr-index',
      keyCondition: 'pnr = :p',
      expressionValues: { ':p': data.pnr },
      limit: 1,
    });
    if (byPnr.length > 0) return respond.conflict(`PNR ${data.pnr} already exists`);

    const now = getISTTimestamp();
    const student = {
      studentId: uuid(),
      ...data,
      status: 'active',
      faceIds: [],
      createdAt: now,
      updatedAt: now,
    };

    await putItem(TABLE_NAMES.STUDENTS, student);

    await logAction({
      actorId: user.userId,
      action: 'CREATE_STUDENT',
      targetEntity: 'student',
      targetId: student.studentId,
    });

    return respond.created(student);
  } catch (err: any) {
    console.error('[STUDENT/CREATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to create student');
  }
};
