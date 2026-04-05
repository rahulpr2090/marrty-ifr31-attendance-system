/**
 * GET /faculty/{facultyId} — Cognito authorized
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, getItem, getPresignedUrl } from '../../lib';
import { TABLE_NAMES, BUCKET_NAMES } from '../../lib/constants';
import type { Faculty } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const facultyId = event.pathParameters?.facultyId;
    if (!facultyId) return respond.badRequest('facultyId is required');

    const faculty = await getItem<Faculty>(TABLE_NAMES.FACULTY, { facultyId });
    if (!faculty) return respond.notFound('Faculty not found');

    let profileUrl: string | null = null;
    if (faculty.profilePhotoKey) {
      profileUrl = await getPresignedUrl(BUCKET_NAMES.PROFILES, faculty.profilePhotoKey);
    }

    return respond.ok({ ...faculty, profileUrl });
  } catch (err) {
    console.error('[FACULTY/GET]', err);
    return respond.serverError('Failed to get faculty');
  }
};
