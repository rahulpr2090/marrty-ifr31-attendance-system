/**
 * GET /attendance/student/{studentId}/percentage
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, queryItems, scanItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { AttendanceRecord } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return respond.badRequest('studentId is required');

    // Get all records for this student
    const { items } = await queryItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      indexName: 'student-date-index',
      keyCondition: 'studentId = :sid',
      expressionValues: { ':sid': studentId },
    });

    // Count unique dates with sessions to approximate total working days
    const uniqueDates = new Set(items.map((r) => r.date));
    const present = items.length;

    // Total = unique dates × 4 sessions (approx)
    const totalPossible = uniqueDates.size * 4 || 1;
    const percentage = Math.round((present / totalPossible) * 100);

    return respond.ok({ studentId, percentage: Math.min(percentage, 100), present, totalDays: uniqueDates.size });
  } catch (err) {
    console.error('[ATTENDANCE/PERCENTAGE]', err);
    return respond.serverError('Failed to calculate percentage');
  }
};
