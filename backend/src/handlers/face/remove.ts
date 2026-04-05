/**
 * DELETE /face/{entityType}/{entityId}/{faceIndex} — Cognito authorized
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { RekognitionClient, DeleteFacesCommand } from '@aws-sdk/client-rekognition';
import { respond, extractUser, getItem, updateItem, deleteFile, logAction } from '../../lib';
import { TABLE_NAMES, BUCKET_NAMES, AWS_CONFIG } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Student, Faculty } from '../../types/models';

const rekognition = new RekognitionClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const { entityType, entityId, faceIndex } = event.pathParameters ?? {};

    if (!entityType || !entityId || faceIndex === undefined) {
      return respond.badRequest('entityType, entityId, and faceIndex are required');
    }

    const tableName = entityType === 'student' ? TABLE_NAMES.STUDENTS : TABLE_NAMES.FACULTY;
    const keyField = entityType === 'student' ? 'studentId' : 'facultyId';
    const entity = await getItem<Student | Faculty>(tableName, { [keyField]: entityId });
    if (!entity) return respond.notFound(`${entityType} not found`);

    const idx = Number(faceIndex);
    if (idx < 0 || idx >= entity.faceIds.length) {
      return respond.badRequest('Invalid face index');
    }

    const faceId = entity.faceIds[idx];

    // Delete from Rekognition
    await rekognition.send(
      new DeleteFacesCommand({
        CollectionId: AWS_CONFIG.COLLECTION_ID,
        FaceIds: [faceId],
      })
    );

    // Delete from S3
    await deleteFile(BUCKET_NAMES.FACE_IMAGES, `${entityType}/${entityId}/${idx}.jpg`);

    // Update DynamoDB
    const newFaceIds = entity.faceIds.filter((_, i) => i !== idx);
    await updateItem({
      tableName,
      key: { [keyField]: entityId },
      updateExpression: 'SET faceIds = :f, updatedAt = :u',
      expressionValues: { ':f': newFaceIds, ':u': getISTTimestamp() },
    });

    await logAction({
      actorId: user.userId,
      action: 'REMOVE_FACE',
      targetEntity: entityType,
      targetId: entityId,
    });

    return respond.ok({ message: 'Face removed', remainingFaces: newFaceIds.length });
  } catch (err: any) {
    console.error('[FACE/REMOVE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to remove face');
  }
};
