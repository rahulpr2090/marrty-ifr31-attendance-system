/**
 * GET /face/{entityType}/{entityId} — Cognito authorized
 *
 * Returns presigned URLs for all enrolled face images.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, getItem, getPresignedUrl } from '../../lib';
import { TABLE_NAMES, BUCKET_NAMES } from '../../lib/constants';
import type { Student, Faculty } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const { entityType, entityId } = event.pathParameters ?? {};
    if (!entityType || !entityId) {
      return respond.badRequest('entityType and entityId are required');
    }

    const tableName = entityType === 'student' ? TABLE_NAMES.STUDENTS : TABLE_NAMES.FACULTY;
    const keyField = entityType === 'student' ? 'studentId' : 'facultyId';
    const entity = await getItem<Student | Faculty>(tableName, { [keyField]: entityId });
    if (!entity) return respond.notFound(`${entityType} not found`);

    const images = await Promise.all(
      entity.faceIds.map(async (faceId, index) => ({
        index,
        faceId,
        url: await getPresignedUrl(BUCKET_NAMES.FACE_IMAGES, `${entityType}/${entityId}/${index}.jpg`),
      }))
    );

    return respond.ok({ entityType, entityId, images, count: images.length });
  } catch (err) {
    console.error('[FACE/GET-IMAGES]', err);
    return respond.serverError('Failed to get face images');
  }
};
