/**
 * Audit Logger
 *
 * Records every significant action for accountability and traceability.
 * All actions are timestamped in IST.
 */

import { v4 as uuid } from 'uuid';
import { putItem } from './db';
import { getISTTimestamp } from './time';
import { TABLE_NAMES } from './constants';

interface AuditParams {
  actorId: string;
  action: string;
  targetEntity: string;
  targetId: string;
  ipAddress?: string;
  latitude?: number;
  longitude?: number;
}

/**
 * Log an auditable action to the audit table.
 * Fire-and-forget — errors are logged but don't break the caller.
 */
export async function logAction(params: AuditParams): Promise<void> {
  try {
    await putItem(TABLE_NAMES.AUDIT, {
      logId: uuid(),
      actorId: params.actorId,
      action: params.action,
      targetEntity: params.targetEntity,
      targetId: params.targetId,
      ipAddress: params.ipAddress,
      latitude: params.latitude,
      longitude: params.longitude,
      timestamp: getISTTimestamp(),
    });
  } catch (err) {
    // Audit failures must not break the main operation
    console.error('[AUDIT] Failed to log action:', err);
  }
}
