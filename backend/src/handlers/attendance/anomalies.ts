/**
 * GET /attendance/anomalies — detect attendance pattern anomalies
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems, queryItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { Student, AttendanceRecord } from '../../types/models';

interface Anomaly {
  studentId: string;
  name: string;
  pattern: string;
  description: string;
  severity: 'info' | 'warning' | 'critical';
}

export const handler: APIGatewayProxyHandler = async () => {
  try {
    const { items: students } = await scanItems<Student>({
      tableName: TABLE_NAMES.STUDENTS,
      filterExpression: '#st = :s',
      expressionValues: { ':s': 'active' },
      expressionNames: { '#st': 'status' },
    });

    // Date range: last 30 days
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const dateFrom = thirtyDaysAgo.toISOString().split('T')[0];
    const dateTo = now.toISOString().split('T')[0];

    const anomalies: Anomaly[] = [];

    for (const student of students) {
      const { items: records } = await queryItems<AttendanceRecord>({
        tableName: TABLE_NAMES.ATTENDANCE,
        indexName: 'student-date-index',
        keyCondition: 'studentId = :sid AND #d BETWEEN :df AND :dt',
        expressionValues: { ':sid': student.studentId, ':df': dateFrom, ':dt': dateTo },
        expressionNames: { '#d': 'date' },
      });

      if (records.length === 0) continue;

      // Pattern 1: Same weekday absence
      const absentDays: Record<number, number> = {};
      const allDates = records.map((r) => new Date(r.date));
      for (let d = new Date(thirtyDaysAgo); d <= now; d.setDate(d.getDate() + 1)) {
        const dayOfWeek = d.getDay();
        if (dayOfWeek === 0) continue; // Skip Sunday
        const dateStr = d.toISOString().split('T')[0];
        const hasRecord = records.some((r) => r.date === dateStr);
        if (!hasRecord) {
          absentDays[dayOfWeek] = (absentDays[dayOfWeek] ?? 0) + 1;
        }
      }

      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (const [day, count] of Object.entries(absentDays)) {
        if (count >= 3) {
          anomalies.push({
            studentId: student.studentId,
            name: student.name,
            pattern: 'weekday_absence',
            description: `Absent every ${dayNames[Number(day)]} for ${count} weeks`,
            severity: count >= 4 ? 'warning' : 'info',
          });
        }
      }

      // Pattern 2: Sudden drop
      const recentRecords = records.filter((r) => r.date >= dateFrom);
      const firstHalf = recentRecords.filter((r) => r.date < dateTo.slice(0, 8) + '15');
      const secondHalf = recentRecords.filter((r) => r.date >= dateTo.slice(0, 8) + '15');
      if (firstHalf.length > 10 && secondHalf.length < firstHalf.length * 0.4) {
        anomalies.push({
          studentId: student.studentId,
          name: student.name,
          pattern: 'sudden_drop',
          description: `Attendance dropped significantly in recent weeks`,
          severity: 'critical',
        });
      }

      // Pattern 3: Morning only
      const morningOnly = records.filter((r) => r.sessionType === 'Morning');
      const afternoon = records.filter((r) => r.sessionType === 'Afternoon');
      if (morningOnly.length > 10 && afternoon.length < morningOnly.length * 0.3) {
        anomalies.push({
          studentId: student.studentId,
          name: student.name,
          pattern: 'morning_only',
          description: 'Attends morning sessions but skips afternoon',
          severity: 'info',
        });
      }
    }

    return respond.ok({ anomalies, count: anomalies.length });
  } catch (err) {
    console.error('[ATTENDANCE/ANOMALIES]', err);
    return respond.serverError('Failed to detect anomalies');
  }
};
