/**
 * GET /faculty — Cognito authorized
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { Faculty } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const params = event.queryStringParameters ?? {};
    const filters: string[] = [];
    const values: Record<string, unknown> = {};
    const names: Record<string, string> = {};

    if (params.status) {
      filters.push('#st = :st');
      values[':st'] = params.status;
      names['#st'] = 'status';
    }
    if (params.search) {
      filters.push('contains(#n, :q)');
      values[':q'] = params.search;
      names['#n'] = 'name';
    }

    const { items } = await scanItems<Faculty>({
      tableName: TABLE_NAMES.FACULTY,
      filterExpression: filters.length > 0 ? filters.join(' AND ') : undefined,
      expressionValues: Object.keys(values).length > 0 ? values : undefined,
      expressionNames: Object.keys(names).length > 0 ? names : undefined,
    });

    return respond.ok({ faculty: items, count: items.length });
  } catch (err) {
    console.error('[FACULTY/LIST]', err);
    return respond.serverError('Failed to list faculty');
  }
};
