/**
 * GET /sessions — Cognito authorized
 *
 * Returns all 4 session configs.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, scanItems } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import type { SessionConfig } from '../../types/models';

export const handler: APIGatewayProxyHandler = async () => {
  try {
    const { items } = await scanItems<SessionConfig>({ tableName: TABLE_NAMES.SESSIONS });

    // Sort by start time
    items.sort((a, b) => a.startTime.localeCompare(b.startTime));

    return respond.ok({ sessions: items });
  } catch (err) {
    console.error('[SESSION/LIST]', err);
    return respond.serverError('Failed to list sessions');
  }
};
