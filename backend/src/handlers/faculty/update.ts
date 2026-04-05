/**
 * PUT /faculty/{facultyId} — HOD only
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, requireRole, getItem, updateItem, logAction } from '../../lib';
import { updateFacultySchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Faculty } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const facultyId = event.pathParameters?.facultyId;
    if (!facultyId) return respond.badRequest('facultyId is required');

    const parsed = updateFacultySchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) return respond.badRequest('Validation failed', parsed.error.flatten());

    const existing = await getItem<Faculty>(TABLE_NAMES.FACULTY, { facultyId });
    if (!existing) return respond.notFound('Faculty not found');

    const fields = Object.entries(parsed.data);
    if (fields.length === 0) return respond.badRequest('No fields to update');

    const expParts: string[] = ['updatedAt = :u'];
    const expValues: Record<string, unknown> = { ':u': getISTTimestamp() };
    const expNames: Record<string, string> = {};

    for (const [key, val] of fields) {
      expParts.push(`#${key} = :${key}`);
      expValues[`:${key}`] = val;
      expNames[`#${key}`] = key;
    }

    await updateItem({
      tableName: TABLE_NAMES.FACULTY,
      key: { facultyId },
      updateExpression: `SET ${expParts.join(', ')}`,
      expressionValues: expValues,
      expressionNames: expNames,
    });

    await logAction({
      actorId: user.userId,
      action: 'UPDATE_FACULTY',
      targetEntity: 'faculty',
      targetId: facultyId,
    });

    return respond.ok({ facultyId, message: 'Faculty updated' });
  } catch (err: any) {
    console.error('[FACULTY/UPDATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to update faculty');
  }
};
