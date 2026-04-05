/**
 * GET /attendance/student/{studentId}/mood — emotion trends by week
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, queryItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { AttendanceRecord, Emotion } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return respond.badRequest('studentId is required');

    const { items } = await queryItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      indexName: 'student-date-index',
      keyCondition: 'studentId = :sid',
      expressionValues: { ':sid': studentId },
      scanForward: false,
    });

    // Group by week
    const weekMap: Record<string, Record<string, number>> = {};
    for (const r of items) {
      if (!r.emotion) continue;
      const date = new Date(r.date);
      const weekStart = new Date(date);
      weekStart.setDate(date.getDate() - date.getDay());
      const weekKey = weekStart.toISOString().split('T')[0];

      if (!weekMap[weekKey]) weekMap[weekKey] = {};
      weekMap[weekKey][r.emotion] = (weekMap[weekKey][r.emotion] ?? 0) + 1;
    }

    const weeks = Object.entries(weekMap).map(([weekStart, breakdown]) => {
      const dominant = Object.entries(breakdown).reduce((a, b) => (a[1] > b[1] ? a : b));
      return { weekStart, dominantEmotion: dominant[0], emotionBreakdown: breakdown };
    }).sort((a, b) => b.weekStart.localeCompare(a.weekStart));

    return respond.ok({ studentId, weeks });
  } catch (err) {
    console.error('[ATTENDANCE/MOOD-TRENDS]', err);
    return respond.serverError('Failed to get mood trends');
  }
};
