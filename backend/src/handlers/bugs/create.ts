/**
 * POST /bugs — create bug report
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, extractUser, putItem } from '../../lib';
import { createBugReportSchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const parsed = createBugReportSchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) return respond.badRequest('Validation failed', parsed.error.flatten());

    const now = getISTTimestamp();
    const report = {
      reportId: uuid(),
      reporterId: user.userId,
      ...parsed.data,
      status: 'Open',
      createdAt: now,
      updatedAt: now,
    };

    await putItem(TABLE_NAMES.BUGS, report);
    return respond.created(report);
  } catch (err: any) {
    console.error('[BUGS/CREATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to create bug report');
  }
};
