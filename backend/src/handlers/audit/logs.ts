/**
 * GET /audit/logs — HOD only
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, requireRole, scanItems } from '../../lib';
import { TABLE_NAMES, LIMITS } from '../../lib/constants';
import type { AuditLog } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    requireRole(event, ['hod']);
    const p = event.queryStringParameters ?? {};
    const limit = Math.min(Number(p.limit) || LIMITS.DEFAULT_PAGE_SIZE, LIMITS.MAX_PAGE_SIZE);
    const lastKey = p.lastKey ? JSON.parse(decodeURIComponent(p.lastKey)) : undefined;

    const filters: string[] = [];
    const values: Record<string, unknown> = {};
    const names: Record<string, string> = {};

    if (p.actorId) { filters.push('actorId = :a'); values[':a'] = p.actorId; }
    if (p.action) { filters.push('#act = :act'); values[':act'] = p.action; names['#act'] = 'action'; }
    if (p.dateFrom) { filters.push('#ts >= :df'); values[':df'] = p.dateFrom; names['#ts'] = 'timestamp'; }
    if (p.dateTo) { filters.push('#ts <= :dt'); values[':dt'] = p.dateTo; if (!names['#ts']) names['#ts'] = 'timestamp'; }

    const { items, lastKey: nextKey } = await scanItems<AuditLog>({
      tableName: TABLE_NAMES.AUDIT,
      filterExpression: filters.length > 0 ? filters.join(' AND ') : undefined,
      expressionValues: Object.keys(values).length > 0 ? values : undefined,
      expressionNames: Object.keys(names).length > 0 ? names : undefined,
      limit, lastKey,
    });

    return respond.ok({ logs: items, count: items.length, nextKey: nextKey ? encodeURIComponent(JSON.stringify(nextKey)) : null });
  } catch (err: any) {
    console.error('[AUDIT/LOGS]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to get audit logs');
  }
};
