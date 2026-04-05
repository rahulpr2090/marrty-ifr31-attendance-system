/**
 * GET /bugs — HOD sees all, lecturers see own
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, extractUser, scanItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { BugReport } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);

    if (user.role === 'hod') {
      const { items } = await scanItems<BugReport>({ tableName: TABLE_NAMES.BUGS });
      return respond.ok({ bugs: items, count: items.length });
    }

    // Lecturers see only their own
    const { items } = await scanItems<BugReport>({
      tableName: TABLE_NAMES.BUGS,
      filterExpression: 'reporterId = :r',
      expressionValues: { ':r': user.userId },
    });

    return respond.ok({ bugs: items, count: items.length });
  } catch (err: any) {
    console.error('[BUGS/LIST]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to list bugs');
  }
};
