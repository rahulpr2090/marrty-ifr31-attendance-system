/**
 * GET /students — Cognito authorized
 *
 * List students with filters and pagination.
 * Uses batch-sem-index GSI when batch+semester provided.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, queryItems, scanItems } from '../../lib';
import { TABLE_NAMES, LIMITS } from '../../lib/constants';
import type { Student } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const params = event.queryStringParameters ?? {};
    const limit = Math.min(Number(params.limit) || LIMITS.DEFAULT_PAGE_SIZE, LIMITS.MAX_PAGE_SIZE);
    const lastKey = params.lastKey ? JSON.parse(decodeURIComponent(params.lastKey)) : undefined;

    // Use GSI if both batch and semester provided
    if (params.batchYear && params.semester) {
      const { items, lastKey: nextKey } = await queryItems<Student>({
        tableName: TABLE_NAMES.STUDENTS,
        indexName: 'batch-sem-index',
        keyCondition: 'batchYear = :b AND semester = :s',
        expressionValues: { ':b': params.batchYear, ':s': params.semester },
        limit,
        lastKey,
      });

      return respond.ok({
        students: items,
        count: items.length,
        nextKey: nextKey ? encodeURIComponent(JSON.stringify(nextKey)) : null,
      });
    }

    // Fallback: scan with filters
    const filters: string[] = [];
    const values: Record<string, unknown> = {};
    const names: Record<string, string> = {};

    if (params.batchYear) {
      filters.push('batchYear = :b');
      values[':b'] = params.batchYear;
    }
    if (params.semester) {
      filters.push('semester = :s');
      values[':s'] = params.semester;
    }
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

    const { items, lastKey: nextKey } = await scanItems<Student>({
      tableName: TABLE_NAMES.STUDENTS,
      filterExpression: filters.length > 0 ? filters.join(' AND ') : undefined,
      expressionValues: Object.keys(values).length > 0 ? values : undefined,
      expressionNames: Object.keys(names).length > 0 ? names : undefined,
      limit,
      lastKey,
    });

    return respond.ok({
      students: items,
      count: items.length,
      nextKey: nextKey ? encodeURIComponent(JSON.stringify(nextKey)) : null,
    });
  } catch (err) {
    console.error('[STUDENT/LIST]', err);
    return respond.serverError('Failed to list students');
  }
};
