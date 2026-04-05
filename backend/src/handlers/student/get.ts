/**
 * GET /students/{studentId} — Cognito authorized
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, getItem, getPresignedUrl } from '../../lib';
import { TABLE_NAMES, BUCKET_NAMES } from '../../lib/constants';
import type { Student } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return respond.badRequest('studentId is required');

    const student = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId });
    if (!student) return respond.notFound('Student not found');

    // Generate presigned URL for profile photo
    let profileUrl: string | null = null;
    if (student.profilePhotoKey) {
      profileUrl = await getPresignedUrl(BUCKET_NAMES.PROFILES, student.profilePhotoKey);
    }

    return respond.ok({ ...student, profileUrl });
  } catch (err) {
    console.error('[STUDENT/GET]', err);
    return respond.serverError('Failed to get student');
  }
};
