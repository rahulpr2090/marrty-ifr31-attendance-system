/**
 * GET /auth/sub-admins — HOD only
 *
 * Lists all users in the "lecturer" group.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  ListUsersInGroupCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { respond, requireRole } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const cognito = new CognitoIdentityProviderClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    requireRole(event, ['hod']);

    const result = await cognito.send(
      new ListUsersInGroupCommand({
        UserPoolId: AWS_CONFIG.USER_POOL_ID,
        GroupName: 'lecturer',
      })
    );

    const subAdmins = (result.Users ?? []).map((u) => {
      const attr = (name: string) =>
        u.Attributes?.find((a) => a.Name === name)?.Value ?? '';

      let permissions = {};
      try {
        permissions = JSON.parse(attr('custom:permissions') || '{}');
      } catch { /* empty */ }

      return {
        userId: attr('sub'),
        email: attr('email'),
        name: attr('name'),
        status: u.UserStatus,
        enabled: u.Enabled,
        permissions,
        createdAt: u.UserCreateDate?.toISOString(),
      };
    });

    return respond.ok({ subAdmins, count: subAdmins.length });
  } catch (err: any) {
    console.error('[AUTH/LIST-SUB-ADMINS]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to list sub-admins');
  }
};
