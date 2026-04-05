/**
 * POST /face/enroll/{entityType}/{entityId} — Cognito authorized
 *
 * Enroll a face image: compress → quality check → index → save.
 * Max 3 images per entity.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  RekognitionClient,
  DetectFacesCommand,
  IndexFacesCommand,
} from '@aws-sdk/client-rekognition';
import { respond, extractUser, getItem, updateItem, uploadFile, logAction } from '../../lib';
import { compressImage } from '../../lib/image';
import { TABLE_NAMES, BUCKET_NAMES, AWS_CONFIG, LIMITS } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Student, Faculty } from '../../types/models';

const rekognition = new RekognitionClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const entityType = event.pathParameters?.entityType;
    const entityId = event.pathParameters?.entityId;

    if (!entityType || !entityId) {
      return respond.badRequest('entityType and entityId are required');
    }
    if (entityType !== 'student' && entityType !== 'faculty') {
      return respond.badRequest('entityType must be "student" or "faculty"');
    }

    // Get entity
    const tableName = entityType === 'student' ? TABLE_NAMES.STUDENTS : TABLE_NAMES.FACULTY;
    const keyField = entityType === 'student' ? 'studentId' : 'facultyId';
    const entity = await getItem<Student | Faculty>(tableName, { [keyField]: entityId });
    if (!entity) return respond.notFound(`${entityType} not found`);

    const currentFaceIds = entity.faceIds ?? [];
    if (currentFaceIds.length >= LIMITS.MAX_FACE_IMAGES) {
      return respond.badRequest(`Maximum ${LIMITS.MAX_FACE_IMAGES} face images allowed`);
    }

    // Decode base64 image from body
    const { image } = JSON.parse(event.body ?? '{}');
    if (!image) return respond.badRequest('image (base64) is required');

    const imageBuffer = Buffer.from(image, 'base64');

    // Step 0: Compress image
    const compressed = await compressImage(imageBuffer);

    // Step 1: Quality check with DetectFaces
    const detectResult = await rekognition.send(
      new DetectFacesCommand({
        Image: { Bytes: compressed.buffer },
        Attributes: ['ALL'],
      })
    );

    const faces = detectResult.FaceDetails ?? [];
    if (faces.length === 0) {
      return respond.badRequest('No face detected in the image');
    }
    if (faces.length > 1) {
      return respond.badRequest('Multiple faces detected. Please upload a single-face image.');
    }

    const face = faces[0];
    if ((face.Confidence ?? 0) < LIMITS.FACE_CONFIDENCE_THRESHOLD) {
      return respond.badRequest(`Face confidence too low: ${face.Confidence?.toFixed(1)}%`);
    }

    // Step 2: Upload to S3
    const faceIndex = currentFaceIds.length;
    const s3Key = `${entityType}/${entityId}/${faceIndex}.jpg`;
    await uploadFile(BUCKET_NAMES.FACE_IMAGES, s3Key, compressed.buffer, 'image/jpeg');

    // Step 3: Index in Rekognition
    const indexResult = await rekognition.send(
      new IndexFacesCommand({
        CollectionId: AWS_CONFIG.COLLECTION_ID,
        Image: { Bytes: compressed.buffer },
        ExternalImageId: `${entityType}#${entityId}`,
        MaxFaces: 1,
        QualityFilter: 'AUTO',
      })
    );

    const indexedFace = indexResult.FaceRecords?.[0]?.Face;
    if (!indexedFace?.FaceId) {
      return respond.serverError('Failed to index face in Rekognition');
    }

    // Step 4: Update entity in DynamoDB
    const newFaceIds = [...currentFaceIds, indexedFace.FaceId];
    await updateItem({
      tableName,
      key: { [keyField]: entityId },
      updateExpression: 'SET faceIds = :f, updatedAt = :u',
      expressionValues: { ':f': newFaceIds, ':u': getISTTimestamp() },
    });

    await logAction({
      actorId: user.userId,
      action: 'ENROLL_FACE',
      targetEntity: entityType,
      targetId: entityId,
    });

    return respond.ok({
      faceId: indexedFace.FaceId,
      index: faceIndex,
      originalSize: compressed.originalSize,
      compressedSize: compressed.compressedSize,
      totalFaces: newFaceIds.length,
    });
  } catch (err: any) {
    console.error('[FACE/ENROLL]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    if (err.name === 'ImageError') return respond.badRequest(err.message);
    return respond.serverError('Failed to enroll face');
  }
};
