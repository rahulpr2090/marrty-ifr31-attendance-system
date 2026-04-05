/**
 * PUT /auth/sub-admins/{userId}/reset-password — HOD only
 *
 * Generates a new temp password for a sub-admin.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminSetUserPasswordCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { respond, requireRole, logAction } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const cognito = new CognitoIdentityProviderClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const userId = event.pathParameters?.userId;

    if (!userId) return respond.badRequest('userId is required');

    // Generate new temp password
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$';
    let tempPassword = '';
    for (let i = 0; i < 12; i++) {
      tempPassword += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    await cognito.send(
      new AdminSetUserPasswordCommand({
        UserPoolId: AWS_CONFIG.USER_POOL_ID,
        Username: userId,
        Password: tempPassword,
        Permanent: false, // Force password change on next login
      })
    );

    await logAction({
      actorId: user.userId,
      action: 'RESET_PASSWORD',
      targetEntity: 'auth',
      targetId: userId,
    });

    return respond.ok({ userId, tempPassword, message: 'Password reset. User must change on next login.' });
  } catch (err: any) {
    console.error('[AUTH/RESET-PASSWORD]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    if (err.name === 'UserNotFoundException') return respond.notFound('User not found');
    return respond.serverError('Password reset failed');
  }
};
