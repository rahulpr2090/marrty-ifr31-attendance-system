/**
 * POST /auth/sub-admins — HOD only
 *
 * Creates a lecturer (sub-admin) in Cognito with temp password.
 * Stores permissions as custom attribute.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminCreateUserCommand,
  AdminAddUserToGroupCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { respond, requireRole, logAction } from '../../lib';
import { createSubAdminSchema } from '../../lib/validators';
import { AWS_CONFIG } from '../../lib/constants';

const cognito = new CognitoIdentityProviderClient({ region: 'ap-south-1' });

/** Generate a secure temp password */
function generateTempPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$';
  let pwd = '';
  for (let i = 0; i < 12; i++) {
    pwd += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return pwd;
}

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const parsed = createSubAdminSchema.safeParse(JSON.parse(event.body ?? '{}'));

    if (!parsed.success) {
      return respond.badRequest('Validation failed', parsed.error.flatten());
    }

    const { email, name, permissions } = parsed.data;
    const tempPassword = generateTempPassword();

    // Create Cognito user
    await cognito.send(
      new AdminCreateUserCommand({
        UserPoolId: AWS_CONFIG.USER_POOL_ID,
        Username: email,
        TemporaryPassword: tempPassword,
        UserAttributes: [
          { Name: 'email', Value: email },
          { Name: 'email_verified', Value: 'true' },
          { Name: 'name', Value: name },
          { Name: 'custom:permissions', Value: JSON.stringify(permissions) },
        ],
        MessageAction: 'SUPPRESS', // Don't send email — HOD shares creds manually
      })
    );

    // Add to lecturer group
    await cognito.send(
      new AdminAddUserToGroupCommand({
        UserPoolId: AWS_CONFIG.USER_POOL_ID,
        Username: email,
        GroupName: 'lecturer',
      })
    );

    await logAction({
      actorId: user.userId,
      action: 'CREATE_SUB_ADMIN',
      targetEntity: 'auth',
      targetId: email,
    });

    return respond.created({ email, name, tempPassword, permissions });
  } catch (err: any) {
    console.error('[AUTH/CREATE-SUB-ADMIN]', err);
    if (err.name === 'UsernameExistsException') {
      return respond.conflict('User with this email already exists');
    }
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to create sub-admin');
  }
};
