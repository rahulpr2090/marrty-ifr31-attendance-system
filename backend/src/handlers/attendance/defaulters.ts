/**
 * GET /attendance/defaulters — students below attendance threshold
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems, queryItems } from '../../lib';
import { TABLE_NAMES, LIMITS } from '../../lib/constants';
import type { Student, AttendanceRecord } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const threshold = Number(event.queryStringParameters?.threshold) || LIMITS.DEFAULT_ATTENDANCE_THRESHOLD;
    const { items: students } = await scanItems<Student>({
      tableName: TABLE_NAMES.STUDENTS,
      filterExpression: '#st = :s',
      expressionValues: { ':s': 'active' },
      expressionNames: { '#st': 'status' },
    });

    const defaulters: { studentId: string; name: string; rollNo: string; percentage: number }[] = [];

    for (const student of students) {
      const { items: records } = await queryItems<AttendanceRecord>({
        tableName: TABLE_NAMES.ATTENDANCE,
        indexName: 'student-date-index',
        keyCondition: 'studentId = :sid',
        expressionValues: { ':sid': student.studentId },
      });

      const uniqueDates = new Set(records.map((r) => r.date));
      const totalPossible = uniqueDates.size * 4 || 1;
      const percentage = Math.round((records.length / totalPossible) * 100);

      if (percentage < threshold) {
        defaulters.push({
          studentId: student.studentId,
          name: student.name,
          rollNo: student.rollNo,
          percentage,
        });
      }
    }

    defaulters.sort((a, b) => a.percentage - b.percentage);
    return respond.ok({ defaulters, threshold, count: defaulters.length });
  } catch (err) {
    console.error('[ATTENDANCE/DEFAULTERS]', err);
    return respond.serverError('Failed to get defaulters');
  }
};
