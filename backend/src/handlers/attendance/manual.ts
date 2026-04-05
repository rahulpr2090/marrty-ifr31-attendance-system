/**
 * POST /attendance/manual — Cognito auth (HOD/lecturer)
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, extractUser, getItem, putItem, queryItems, logAction } from '../../lib';
import { manualAttendanceSchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp, getISTTime } from '../../lib/time';
import type { Student, AttendanceRecord } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const parsed = manualAttendanceSchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) return respond.badRequest('Validation failed', parsed.error.flatten());

    const { studentIds, sessionType, date, reason } = parsed.data;
    const now = getISTTimestamp();
    let marked = 0;
    const skipped: { studentId: string; reason: string }[] = [];

    for (const studentId of studentIds) {
      const student = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId });
      if (!student) { skipped.push({ studentId, reason: 'Not found' }); continue; }

      const { items } = await queryItems<AttendanceRecord>({
        tableName: TABLE_NAMES.ATTENDANCE,
        indexName: 'student-date-index',
        keyCondition: 'studentId = :sid AND #d = :date',
        expressionValues: { ':sid': studentId, ':date': date },
        expressionNames: { '#d': 'date' },
      });
      if (items.find((r) => r.sessionType === sessionType)) {
        skipped.push({ studentId, reason: 'Already marked' }); continue;
      }

      await putItem(TABLE_NAMES.ATTENDANCE, {
        recordId: uuid(), studentId, sessionType, date,
        time: getISTTime(), method: 'manual', markedBy: user.userId,
        createdAt: now,
      });
      marked++;
    }

    await logAction({ actorId: user.userId, action: 'MANUAL_ATTENDANCE', targetEntity: 'attendance', targetId: `${marked} records` });
    return respond.ok({ marked, skipped, reason });
  } catch (err: any) {
    console.error('[ATTENDANCE/MANUAL]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Manual attendance failed');
  }
};
