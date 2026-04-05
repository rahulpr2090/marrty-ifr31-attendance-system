/**
 * GET /attendance/records — filtered + paginated
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems } from '../../lib';
import { TABLE_NAMES, LIMITS } from '../../lib/constants';
import type { AttendanceRecord } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const p = event.queryStringParameters ?? {};
    const limit = Math.min(Number(p.limit) || LIMITS.DEFAULT_PAGE_SIZE, LIMITS.MAX_PAGE_SIZE);
    const lastKey = p.lastKey ? JSON.parse(decodeURIComponent(p.lastKey)) : undefined;
    const filters: string[] = [];
    const values: Record<string, unknown> = {};
    const names: Record<string, string> = {};

    if (p.dateFrom) { filters.push('#d >= :df'); values[':df'] = p.dateFrom; names['#d'] = 'date'; }
    if (p.dateTo) { filters.push('#d <= :dt'); values[':dt'] = p.dateTo; if (!names['#d']) names['#d'] = 'date'; }
    if (p.studentId) { filters.push('studentId = :sid'); values[':sid'] = p.studentId; }
    if (p.sessionType) { filters.push('sessionType = :st'); values[':st'] = p.sessionType; }
    if (p.method) { filters.push('#m = :m'); values[':m'] = p.method; names['#m'] = 'method'; }

    const { items, lastKey: nextKey } = await scanItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      filterExpression: filters.length > 0 ? filters.join(' AND ') : undefined,
      expressionValues: Object.keys(values).length > 0 ? values : undefined,
      expressionNames: Object.keys(names).length > 0 ? names : undefined,
      limit, lastKey,
    });

    return respond.ok({ records: items, count: items.length, nextKey: nextKey ? encodeURIComponent(JSON.stringify(nextKey)) : null });
  } catch (err) {
    console.error('[ATTENDANCE/RECORDS]', err);
    return respond.serverError('Failed to get records');
  }
};
