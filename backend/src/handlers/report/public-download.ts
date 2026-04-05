/**
 * GET /reports/public/{shareToken} — NO auth (public download link)
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, getItem, getPresignedUrl } from '../../lib';
import { BUCKET_NAMES } from '../../lib/constants';

const SHARE_TABLE = process.env.SHARE_TABLE ?? 'marrty-shared-reports';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const shareToken = event.pathParameters?.shareToken;
    if (!shareToken) return respond.badRequest('shareToken is required');

    const record = await getItem<{ shareToken: string; s3Key: string; expiresAt: string }>(
      SHARE_TABLE,
      { shareToken }
    );

    if (!record) return respond.notFound('Share link not found');

    // Check expiry
    if (new Date(record.expiresAt) < new Date()) {
      return respond.gone('Share link has expired (48h limit)');
    }

    // Redirect to presigned S3 URL
    const downloadUrl = await getPresignedUrl(BUCKET_NAMES.EXPORTS, record.s3Key, 600);

    return {
      statusCode: 302,
      headers: { Location: downloadUrl },
      body: '',
    };
  } catch (err) {
    console.error('[REPORT/PUBLIC-DOWNLOAD]', err);
    return respond.serverError('Download failed');
  }
};
