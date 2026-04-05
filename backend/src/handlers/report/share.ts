/**
 * POST /reports/share — generate shareable link (48h expiry)
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, extractUser, putItem } from '../../lib';
import { TABLE_NAMES } from '../../lib/constants';
import { getISTTimestamp } from '../../lib/time';

const SHARE_TABLE = process.env.SHARE_TABLE ?? 'marrty-shared-reports';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const { reportId, s3Key } = JSON.parse(event.body ?? '{}');
    if (!s3Key) return respond.badRequest('s3Key is required');

    const shareToken = uuid();
    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString();

    await putItem(SHARE_TABLE, {
      shareToken,
      s3Key,
      reportId: reportId ?? s3Key,
      createdBy: user.userId,
      expiresAt,
      createdAt: getISTTimestamp(),
    });

    const apiUrl = process.env.API_URL ?? '';
    return respond.ok({
      shareUrl: `${apiUrl}/reports/public/${shareToken}`,
      shareToken,
      expiresAt,
    });
  } catch (err: any) {
    console.error('[REPORT/SHARE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to create share link');
  }
};
