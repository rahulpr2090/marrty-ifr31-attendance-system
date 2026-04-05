/**
 * POST /students/mark-passout — Cognito authorized
 *
 * Mark students as passed out and remove their faces from Rekognition.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { RekognitionClient, DeleteFacesCommand } from '@aws-sdk/client-rekognition';
import { respond, extractUser, getItem, updateItem, logAction } from '../../lib';
import { TABLE_NAMES, AWS_CONFIG } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';
import type { Student } from '../../types/models';

const rekognition = new RekognitionClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const { studentIds } = JSON.parse(event.body ?? '{}');

    if (!Array.isArray(studentIds) || studentIds.length === 0) {
      return respond.badRequest('studentIds array is required');
    }

    const now = getISTTimestamp();
    const processed: string[] = [];
    const errors: { studentId: string; reason: string }[] = [];

    for (const id of studentIds) {
      const student = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId: id });
      if (!student) {
        errors.push({ studentId: id, reason: 'Not found' });
        continue;
      }

      // Delete faces from Rekognition
      if (student.faceIds.length > 0) {
        try {
          await rekognition.send(
            new DeleteFacesCommand({
              CollectionId: AWS_CONFIG.COLLECTION_ID,
              FaceIds: student.faceIds,
            })
          );
        } catch (err) {
          console.warn(`[PASSOUT] Failed to delete faces for ${id}:`, err);
        }
      }

      // Update status
      await updateItem({
        tableName: TABLE_NAMES.STUDENTS,
        key: { studentId: id },
        updateExpression: 'SET #st = :s, faceIds = :f, updatedAt = :u',
        expressionValues: { ':s': 'passout', ':f': [], ':u': now },
        expressionNames: { '#st': 'status' },
      });

      processed.push(id);
    }

    await logAction({
      actorId: user.userId,
      action: 'MARK_PASSOUT',
      targetEntity: 'student',
      targetId: `${processed.length} students`,
    });

    return respond.ok({ processed, errors, count: processed.length });
  } catch (err: any) {
    console.error('[STUDENT/MARK-PASSOUT]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to mark passout');
  }
};
