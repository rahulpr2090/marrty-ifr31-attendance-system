/**
 * GET /sessions/active — Cognito authorized
 *
 * Returns the currently active session based on IST time.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTHoursMinutes, isTimeBetween } from '../../lib/time';
import type { SessionConfig } from '../../types/models';

export const handler: APIGatewayProxyHandler = async () => {
  try {
    const { items } = await scanItems<SessionConfig>({ tableName: TABLE_NAMES.SESSIONS });
    const { hours, minutes } = getISTHoursMinutes();
    const currentTime = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;

    const active = items.find(
      (s) => s.isActive && isTimeBetween(currentTime, s.startTime, s.endTime)
    );

    return respond.ok({
      active: active ?? null,
      currentTime,
      message: active ? `Active session: ${active.name}` : 'No active session right now',
    });
  } catch (err) {
    console.error('[SESSION/GET-ACTIVE]', err);
    return respond.serverError('Failed to get active session');
  }
};
