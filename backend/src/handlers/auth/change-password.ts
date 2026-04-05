/**
 * POST /auth/change-password — Public (no authorizer)
 *
 * Two modes:
 * 1. First login (NEW_PASSWORD_REQUIRED challenge): { email, session, newPassword }
 * 2. Regular change: { accessToken, previousPassword, newPassword }
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminRespondToAuthChallengeCommand,
  ChangePasswordCommand,
  AssociateSoftwareTokenCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { respond } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const cognito = new CognitoIdentityProviderClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const body = JSON.parse(event.body ?? '{}');

    // Mode 1: First-login forced password change
    if (body.session && body.email) {
      if (!body.newPassword) {
        return respond.badRequest('newPassword is required');
      }

      const result = await cognito.send(
        new AdminRespondToAuthChallengeCommand({
          UserPoolId: AWS_CONFIG.USER_POOL_ID,
          ClientId: AWS_CONFIG.CLIENT_ID,
          ChallengeName: 'NEW_PASSWORD_REQUIRED',
          Session: body.session,
          ChallengeResponses: {
            USERNAME: body.email,
            NEW_PASSWORD: body.newPassword,
          },
        })
      );

      // After password change, MFA_SETUP challenge may follow
      if (result.ChallengeName === 'MFA_SETUP') {
        // Generate TOTP secret for authenticator app
        const tokenResult = await cognito.send(
          new AssociateSoftwareTokenCommand({ Session: result.Session })
        );
        return respond.ok({
          challenge: 'MFA_SETUP',
          session: tokenResult.Session,
          secretCode: tokenResult.SecretCode,
          message: 'Password changed. Scan QR code in Authenticator app.',
        });
      }

      if (result.ChallengeName) {
        return respond.ok({
          challenge: result.ChallengeName,
          session: result.Session,
        });
      }

      // MFA optional — tokens returned directly
      if (result.AuthenticationResult) {
        const tokens = result.AuthenticationResult;
        return respond.ok({
          accessToken: tokens.AccessToken,
          refreshToken: tokens.RefreshToken,
          idToken: tokens.IdToken,
          expiresIn: tokens.ExpiresIn,
        });
      }

      return respond.ok({ message: 'Password changed successfully' });
    }

    // Mode 2: Regular password change (authenticated)
    if (body.accessToken && body.previousPassword && body.newPassword) {
      await cognito.send(
        new ChangePasswordCommand({
          AccessToken: body.accessToken,
          PreviousPassword: body.previousPassword,
          ProposedPassword: body.newPassword,
        })
      );

      return respond.ok({ message: 'Password changed successfully' });
    }

    return respond.badRequest(
      'Provide either { email, session, newPassword } or { accessToken, previousPassword, newPassword }'
    );
  } catch (err: any) {
    console.error('[AUTH/CHANGE-PASSWORD]', err);
    if (err.name === 'InvalidPasswordException') {
      return respond.badRequest('Password does not meet policy requirements');
    }
    if (err.name === 'NotAuthorizedException') {
      return respond.unauthorized('Session expired or incorrect password');
    }
    return respond.serverError('Password change failed');
  }
};
