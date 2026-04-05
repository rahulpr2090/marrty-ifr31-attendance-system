/**
 * GET /attendance/student/{studentId}/history
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, queryItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { AttendanceRecord } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return respond.badRequest('studentId is required');

    const p = event.queryStringParameters ?? {};

    const { items } = await queryItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      indexName: 'student-date-index',
      keyCondition: p.dateFrom && p.dateTo
        ? 'studentId = :sid AND #d BETWEEN :df AND :dt'
        : 'studentId = :sid',
      expressionValues: {
        ':sid': studentId,
        ...(p.dateFrom ? { ':df': p.dateFrom } : {}),
        ...(p.dateTo ? { ':dt': p.dateTo } : {}),
      },
      expressionNames: p.dateFrom ? { '#d': 'date' } : undefined,
      scanForward: false,
    });

    const present = items.filter((r) => r.method !== 'manual').length;
    const late = items.filter((r) => r.time && r.sessionType).length; // approximation

    return respond.ok({ studentId, records: items, totalPresent: present, totalRecords: items.length });
  } catch (err) {
    console.error('[ATTENDANCE/STUDENT-HISTORY]', err);
    return respond.serverError('Failed to get history');
  }
};
