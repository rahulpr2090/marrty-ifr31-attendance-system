/**
 * GET /attendance/today — today's summary by session
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTDate } from '../../lib/time';
import type { AttendanceRecord } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const today = event.queryStringParameters?.date ?? getISTDate();

    const { items } = await scanItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      filterExpression: '#d = :date',
      expressionValues: { ':date': today },
      expressionNames: { '#d': 'date' },
    });

    // Group by session
    const sessionMap: Record<string, { present: number; late: number; students: Set<string> }> = {};
    for (const r of items) {
      if (!sessionMap[r.sessionType]) {
        sessionMap[r.sessionType] = { present: 0, late: 0, students: new Set() };
      }
      sessionMap[r.sessionType].students.add(r.studentId);
      sessionMap[r.sessionType].present++;
    }

    const sessions = Object.entries(sessionMap).map(([name, data]) => ({
      name,
      present: data.present,
      uniqueStudents: data.students.size,
    }));

    return respond.ok({ date: today, sessions, totalScans: items.length });
  } catch (err) {
    console.error('[ATTENDANCE/TODAY]', err);
    return respond.serverError('Failed to get today summary');
  }
};
