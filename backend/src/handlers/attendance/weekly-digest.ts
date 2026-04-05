/**
 * GET /attendance/digest?week=2026-W14 — auto-generated weekly summary
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { AttendanceRecord, Student } from '../../types/models';

function getWeekDateRange(weekStr?: string): { start: string; end: string } {
  const now = new Date();
  if (weekStr) {
    const [year, week] = weekStr.split('-W').map(Number);
    const jan1 = new Date(year, 0, 1);
    const startDay = jan1.getDay();
    const start = new Date(jan1.getTime() + ((week - 1) * 7 - startDay + 1) * 86400000);
    const end = new Date(start.getTime() + 6 * 86400000);
    return { start: start.toISOString().split('T')[0], end: end.toISOString().split('T')[0] };
  }
  // Default: current week
  const start = new Date(now);
  start.setDate(now.getDate() - now.getDay() + 1);
  return { start: start.toISOString().split('T')[0], end: now.toISOString().split('T')[0] };
}

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const weekParam = event.queryStringParameters?.week;
    const { start, end } = getWeekDateRange(weekParam);

    const { items: records } = await scanItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      filterExpression: '#d BETWEEN :s AND :e',
      expressionValues: { ':s': start, ':e': end },
      expressionNames: { '#d': 'date' },
    });

    // Total scans
    const totalScans = records.length;
    const uniqueStudents = new Set(records.map((r) => r.studentId)).size;

    // Mood distribution
    const moodDist: Record<string, number> = {};
    for (const r of records) {
      if (r.emotion) moodDist[r.emotion] = (moodDist[r.emotion] ?? 0) + 1;
    }

    // Session breakdown
    const sessionBreakdown: Record<string, number> = {};
    for (const r of records) {
      sessionBreakdown[r.sessionType] = (sessionBreakdown[r.sessionType] ?? 0) + 1;
    }

    return respond.ok({
      week: weekParam ?? `${start} to ${end}`,
      dateRange: { start, end },
      totalScans,
      uniqueStudents,
      sessionBreakdown,
      moodDistribution: moodDist,
    });
  } catch (err) {
    console.error('[ATTENDANCE/WEEKLY-DIGEST]', err);
    return respond.serverError('Failed to generate digest');
  }
};
