/**
 * POST /face/search — API Key auth (for device/mobile)
 *
 * Anti-spoofing check → search face → return match + emotion.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  RekognitionClient,
  DetectFacesCommand,
  SearchFacesByImageCommand,
} from '@aws-sdk/client-rekognition';
import { respond, getItem } from '../../lib';
import { TABLE_NAMES, AWS_CONFIG, LIMITS } from '../../lib/constants';
import type { Student, Faculty, FaceSearchResult } from '../../types/models';

const rekognition = new RekognitionClient({ region: 'ap-south-1' });

/** Anti-spoofing: checks eyes open, quality, pose */
async function antiSpoofCheck(imageBytes: Uint8Array): Promise<{ pass: boolean; reason?: string; emotion?: string; emotionConfidence?: number }> {
  const result = await rekognition.send(
    new DetectFacesCommand({
      Image: { Bytes: imageBytes },
      Attributes: ['ALL'],
    })
  );

  const faces = result.FaceDetails ?? [];
  if (faces.length === 0) return { pass: false, reason: 'No face detected' };

  const face = faces[0];

  // Eyes must be open
  if ((face.EyesOpen?.Confidence ?? 0) < 80 || !face.EyesOpen?.Value) {
    return { pass: false, reason: 'Eyes must be open' };
  }

  // Quality check (brightness + sharpness)
  const quality = face.Quality;
  if ((quality?.Brightness ?? 0) < 40 || (quality?.Sharpness ?? 0) < 40) {
    return { pass: false, reason: 'Image quality too low (brightness/sharpness)' };
  }

  // Pose check (±30°)
  const pose = face.Pose;
  if (Math.abs(pose?.Yaw ?? 0) > 30 || Math.abs(pose?.Pitch ?? 0) > 30) {
    return { pass: false, reason: 'Face angle too extreme — look straight at the camera' };
  }

  // Extract dominant emotion
  const emotions = face.Emotions ?? [];
  const dominant = emotions.reduce((a, b) => ((a.Confidence ?? 0) > (b.Confidence ?? 0) ? a : b), emotions[0]);

  return {
    pass: true,
    emotion: dominant?.Type,
    emotionConfidence: dominant?.Confidence,
  };
}

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const { image, deviceId } = JSON.parse(event.body ?? '{}');
    if (!image) return respond.badRequest('image (base64) is required');

    const imageBytes = Buffer.from(image, 'base64');

    // Step 1: Anti-spoofing
    const spoof = await antiSpoofCheck(imageBytes);
    if (!spoof.pass) {
      return respond.ok({
        matched: false,
        reason: spoof.reason,
        spoofing: true,
      } as FaceSearchResult);
    }

    // Step 2: Search face in collection
    let searchResult;
    try {
      searchResult = await rekognition.send(
        new SearchFacesByImageCommand({
          CollectionId: AWS_CONFIG.COLLECTION_ID,
          Image: { Bytes: imageBytes },
          FaceMatchThreshold: LIMITS.FACE_CONFIDENCE_THRESHOLD,
          MaxFaces: 1,
        })
      );
    } catch (err: any) {
      if (err.name === 'InvalidParameterException') {
        return respond.ok({ matched: false, reason: 'No face detected in image' } as FaceSearchResult);
      }
      throw err;
    }

    const matches = searchResult.FaceMatches ?? [];
    if (matches.length === 0) {
      return respond.ok({
        matched: false,
        reason: 'Face not recognized',
        emotion: spoof.emotion,
        emotionConfidence: spoof.emotionConfidence,
      } as FaceSearchResult);
    }

    // Step 3: Parse match
    const match = matches[0];
    const externalId = match.Face?.ExternalImageId ?? '';
    const [entityType, entityId] = externalId.split('#');
    const confidence = match.Similarity ?? 0;

    // Fetch entity name
    let name = 'Unknown';
    if (entityType === 'student') {
      const student = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId: entityId });
      name = student?.name ?? 'Unknown';
    } else if (entityType === 'faculty') {
      const faculty = await getItem<Faculty>(TABLE_NAMES.FACULTY, { facultyId: entityId });
      name = faculty?.name ?? 'Unknown';
    }

    return respond.ok({
      matched: true,
      entityType,
      entityId,
      name,
      confidence,
      emotion: spoof.emotion,
      emotionConfidence: spoof.emotionConfidence,
    } as FaceSearchResult);
  } catch (err) {
    console.error('[FACE/SEARCH]', err);
    return respond.serverError('Face search failed');
  }
};
