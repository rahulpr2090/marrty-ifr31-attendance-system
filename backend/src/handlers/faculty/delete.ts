/**
 * DELETE /faculty/{facultyId} — HOD only, soft delete
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, requireRole, getItem, updateItem, logAction } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Faculty } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const facultyId = event.pathParameters?.facultyId;
    if (!facultyId) return respond.badRequest('facultyId is required');

    const existing = await getItem<Faculty>(TABLE_NAMES.FACULTY, { facultyId });
    if (!existing) return respond.notFound('Faculty not found');

    await updateItem({
      tableName: TABLE_NAMES.FACULTY,
      key: { facultyId },
      updateExpression: 'SET #st = :s, updatedAt = :u',
      expressionValues: { ':s': 'inactive', ':u': getISTTimestamp() },
      expressionNames: { '#st': 'status' },
    });

    await logAction({
      actorId: user.userId,
      action: 'DELETE_FACULTY',
      targetEntity: 'faculty',
      targetId: facultyId,
    });

    return respond.ok({ facultyId, message: 'Faculty deactivated' });
  } catch (err: any) {
    console.error('[FACULTY/DELETE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to delete faculty');
  }
};
