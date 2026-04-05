/**
 * DELETE /auth/sub-admins/{userId} — HOD only
 *
 * Disables and deletes a sub-admin from Cognito.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminDisableUserCommand,
  AdminDeleteUserCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { respond, requireRole, logAction } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const cognito = new CognitoIdentityProviderClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const userId = event.pathParameters?.userId;

    if (!userId) return respond.badRequest('userId is required');

    // Disable first, then delete
    await cognito.send(
      new AdminDisableUserCommand({
        UserPoolId: AWS_CONFIG.USER_POOL_ID,
        Username: userId,
      })
    );

    await cognito.send(
      new AdminDeleteUserCommand({
        UserPoolId: AWS_CONFIG.USER_POOL_ID,
        Username: userId,
      })
    );

    await logAction({
      actorId: user.userId,
      action: 'DELETE_SUB_ADMIN',
      targetEntity: 'auth',
      targetId: userId,
    });

    return respond.ok({ message: 'Sub-admin deleted', userId });
  } catch (err: any) {
    console.error('[AUTH/DELETE-SUB-ADMIN]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    if (err.name === 'UserNotFoundException') return respond.notFound('User not found');
    return respond.serverError('Failed to delete sub-admin');
  }
};
