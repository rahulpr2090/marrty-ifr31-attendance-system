/**
 * PUT /sessions/{sessionId} — HOD only
 *
 * Update a session's start/end times. Validates start < end.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, requireRole, getItem, updateItem, logAction } from '../../lib';
import { updateSessionSchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { SessionConfig } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const sessionId = event.pathParameters?.sessionId;
    if (!sessionId) return respond.badRequest('sessionId is required');

    const parsed = updateSessionSchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) {
      return respond.badRequest('Validation failed', parsed.error.flatten());
    }

    // Validate start < end
    const { startTime, endTime } = parsed.data;
    if (startTime >= endTime) {
      return respond.badRequest('startTime must be before endTime');
    }

    // Check session exists
    const existing = await getItem<SessionConfig>(TABLE_NAMES.SESSIONS, { sessionId });
    if (!existing) return respond.notFound('Session not found');

    await updateItem({
      tableName: TABLE_NAMES.SESSIONS,
      key: { sessionId },
      updateExpression: 'SET startTime = :s, endTime = :e, updatedAt = :u',
      expressionValues: { ':s': startTime, ':e': endTime, ':u': getISTTimestamp() },
    });

    await logAction({
      actorId: user.userId,
      action: 'UPDATE_SESSION',
      targetEntity: 'session',
      targetId: sessionId,
    });

    return respond.ok({ sessionId, startTime, endTime, message: 'Session updated' });
  } catch (err: any) {
    console.error('[SESSION/UPDATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to update session');
  }
};
