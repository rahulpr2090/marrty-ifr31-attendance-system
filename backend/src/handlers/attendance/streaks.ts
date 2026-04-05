/**
 * GET /attendance/streaks — top 10 streak leaderboard
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems, queryItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { Student, AttendanceRecord } from '../../types/models';

export const handler: APIGatewayProxyHandler = async () => {
  try {
    const { items: students } = await scanItems<Student>({
      tableName: TABLE_NAMES.STUDENTS,
      filterExpression: '#st = :s',
      expressionValues: { ':s': 'active' },
      expressionNames: { '#st': 'status' },
    });

    const streaks: { studentId: string; name: string; rollNo: string; streak: number; lastDate: string }[] = [];

    for (const student of students) {
      const { items: records } = await queryItems<AttendanceRecord>({
        tableName: TABLE_NAMES.ATTENDANCE,
        indexName: 'student-date-index',
        keyCondition: 'studentId = :sid',
        expressionValues: { ':sid': student.studentId },
        scanForward: false,
        limit: 60,
      });

      if (records.length === 0) continue;

      // Count consecutive days
      const dates = [...new Set(records.map((r) => r.date))].sort().reverse();
      let streak = 1;
      for (let i = 1; i < dates.length; i++) {
        const prev = new Date(dates[i - 1]);
        const curr = new Date(dates[i]);
        const diff = (prev.getTime() - curr.getTime()) / (1000 * 60 * 60 * 24);
        if (diff <= 1.5) streak++; // Allow weekends
        else break;
      }

      streaks.push({
        studentId: student.studentId,
        name: student.name,
        rollNo: student.rollNo,
        streak,
        lastDate: dates[0],
      });
    }

    streaks.sort((a, b) => b.streak - a.streak);
    return respond.ok({ streaks: streaks.slice(0, 10) });
  } catch (err) {
    console.error('[ATTENDANCE/STREAKS]', err);
    return respond.serverError('Failed to get streaks');
  }
};
