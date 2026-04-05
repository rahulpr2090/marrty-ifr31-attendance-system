/**
 * POST /sessions/init — HOD only
 *
 * Creates 4 default sessions if they don't already exist.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, requireRole, putItem, getItem, logAction } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { SessionConfig } from '../../types/models';

const DEFAULT_SESSIONS: Omit<SessionConfig, 'sessionId' | 'updatedAt'>[] = [
  { name: 'Morning',   startTime: '08:30', endTime: '10:00', isActive: true },
  { name: 'Interval',  startTime: '10:30', endTime: '12:00', isActive: true },
  { name: 'Afternoon', startTime: '12:30', endTime: '15:30', isActive: true },
  { name: 'Evening',   startTime: '16:00', endTime: '17:00', isActive: true },
];

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const now = getISTTimestamp();
    const created: string[] = [];
    const skipped: string[] = [];

    for (const session of DEFAULT_SESSIONS) {
      // Check if session already exists by name
      const existing = await getItem<SessionConfig>(
        TABLE_NAMES.SESSIONS,
        { sessionId: session.name }
      );

      if (existing) {
        skipped.push(session.name);
        continue;
      }

      await putItem(TABLE_NAMES.SESSIONS, {
        sessionId: session.name,
        ...session,
        updatedAt: now,
      });
      created.push(session.name);
    }

    await logAction({
      actorId: user.userId,
      action: 'INIT_SESSIONS',
      targetEntity: 'session',
      targetId: 'all',
    });

    return respond.ok({ created, skipped, message: `${created.length} sessions created` });
  } catch (err: any) {
    console.error('[SESSION/INIT]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to initialize sessions');
  }
};
