/**
 * PUT /bugs/{reportId} — HOD only, update status
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, requireRole, getItem, updateItem, logAction } from '../../lib';
import { updateBugStatusSchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { BugReport } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const reportId = event.pathParameters?.reportId;
    if (!reportId) return respond.badRequest('reportId is required');

    const parsed = updateBugStatusSchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) return respond.badRequest('Validation failed', parsed.error.flatten());

    const existing = await getItem<BugReport>(TABLE_NAMES.BUGS, { reportId });
    if (!existing) return respond.notFound('Bug report not found');

    await updateItem({
      tableName: TABLE_NAMES.BUGS,
      key: { reportId },
      updateExpression: 'SET #st = :s, updatedAt = :u',
      expressionValues: { ':s': parsed.data.status, ':u': getISTTimestamp() },
      expressionNames: { '#st': 'status' },
    });

    await logAction({ actorId: user.userId, action: 'UPDATE_BUG_STATUS', targetEntity: 'bug', targetId: reportId });
    return respond.ok({ reportId, status: parsed.data.status, message: 'Bug status updated' });
  } catch (err: any) {
    console.error('[BUGS/UPDATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to update bug');
  }
};
