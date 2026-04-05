/**
 * POST /auth/verify-mfa — Public (no authorizer)
 *
 * Handles two MFA scenarios:
 * - MFA_SETUP: VerifySoftwareToken to associate the authenticator
 * - SOFTWARE_TOKEN_MFA: RespondToAuthChallenge with TOTP code
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  VerifySoftwareTokenCommand,
  AdminRespondToAuthChallengeCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { respond } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const cognito = new CognitoIdentityProviderClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const { session, code, challengeName } = JSON.parse(event.body ?? '{}');

    if (!session || !code || !challengeName) {
      return respond.badRequest('session, code, and challengeName are required');
    }

    if (challengeName === 'MFA_SETUP') {
      // Verify and associate the TOTP device
      const result = await cognito.send(
        new VerifySoftwareTokenCommand({
          Session: session,
          UserCode: code,
        })
      );

      if (result.Status === 'SUCCESS') {
        return respond.ok({ message: 'MFA setup complete. Please login again.' });
      }
      return respond.badRequest('Invalid code. Please try again.');
    }

    if (challengeName === 'SOFTWARE_TOKEN_MFA') {
      // Respond to the MFA challenge with the TOTP code
      const result = await cognito.send(
        new AdminRespondToAuthChallengeCommand({
          UserPoolId: AWS_CONFIG.USER_POOL_ID,
          ClientId: AWS_CONFIG.CLIENT_ID,
          ChallengeName: 'SOFTWARE_TOKEN_MFA',
          Session: session,
          ChallengeResponses: {
            USERNAME: 'PLACEHOLDER', // Cognito session carries the username
            SOFTWARE_TOKEN_MFA_CODE: code,
          },
        })
      );

      const tokens = result.AuthenticationResult;
      if (!tokens) {
        return respond.badRequest('Invalid code or session expired');
      }

      return respond.ok({
        accessToken: tokens.AccessToken,
        refreshToken: tokens.RefreshToken,
        idToken: tokens.IdToken,
        expiresIn: tokens.ExpiresIn,
      });
    }

    return respond.badRequest(`Unsupported challenge: ${challengeName}`);
  } catch (err: any) {
    console.error('[AUTH/VERIFY-MFA]', err);
    if (err.name === 'CodeMismatchException') {
      return respond.badRequest('Invalid verification code');
    }
    if (err.name === 'ExpiredCodeException' || err.name === 'NotAuthorizedException') {
      return respond.unauthorized('Session expired. Please login again.');
    }
    return respond.serverError('MFA verification failed');
  }
};
