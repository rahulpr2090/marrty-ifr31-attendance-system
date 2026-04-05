/**
 * POST /faculty — HOD only
 *
 * Create a faculty member. Auto-generates systemId (FAC-0001 format).
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, requireRole, putItem, scanItems, logAction } from '../../lib';
import { createFacultySchema } from '../../lib/validators';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Faculty } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const parsed = createFacultySchema.safeParse(JSON.parse(event.body ?? '{}'));

    if (!parsed.success) {
      return respond.badRequest('Validation failed', parsed.error.flatten());
    }

    // Auto-generate systemId
    const { items: allFaculty } = await scanItems<Faculty>({
      tableName: TABLE_NAMES.FACULTY,
    });
    const nextNum = allFaculty.length + 1;
    const systemId = `FAC-${String(nextNum).padStart(4, '0')}`;

    const now = getISTTimestamp();
    const faculty = {
      facultyId: uuid(),
      systemId,
      ...parsed.data,
      status: 'active',
      faceIds: [],
      createdAt: now,
      updatedAt: now,
    };

    await putItem(TABLE_NAMES.FACULTY, faculty);

    await logAction({
      actorId: user.userId,
      action: 'CREATE_FACULTY',
      targetEntity: 'faculty',
      targetId: faculty.facultyId,
    });

    return respond.created(faculty);
  } catch (err: any) {
    console.error('[FACULTY/CREATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to create faculty');
  }
};
