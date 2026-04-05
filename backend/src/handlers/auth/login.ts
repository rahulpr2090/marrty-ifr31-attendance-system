/**
 * POST /auth/login — Public (no authorizer)
 *
 * Handles the full Cognito login flow including MFA challenges:
 * 1. NEW_PASSWORD_REQUIRED → return challenge + session
 * 2. MFA_SETUP → return TOTP secret for authenticator app
 * 3. SOFTWARE_TOKEN_MFA → return challenge, user sends 6-digit code
 * 4. Success → return tokens + user info
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import {
  CognitoIdentityProviderClient,
  AdminInitiateAuthCommand,
  AssociateSoftwareTokenCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { respond } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const cognito = new CognitoIdentityProviderClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const body = JSON.parse(event.body ?? '{}');
    const { email, password } = body;

    if (!email || !password) {
      return respond.badRequest('Email and password are required');
    }

    // Step 1: Initiate auth
    const authResult = await cognito.send(
      new AdminInitiateAuthCommand({
        UserPoolId: AWS_CONFIG.USER_POOL_ID,
        ClientId: AWS_CONFIG.CLIENT_ID,
        AuthFlow: 'ADMIN_USER_PASSWORD_AUTH',
        AuthParameters: {
          USERNAME: email,
          PASSWORD: password,
        },
      })
    );

    // Handle challenges
    if (authResult.ChallengeName) {
      switch (authResult.ChallengeName) {
        case 'NEW_PASSWORD_REQUIRED':
          return respond.ok({
            challenge: 'NEW_PASSWORD_REQUIRED',
            session: authResult.Session,
            message: 'Please set a new password',
          });

        case 'MFA_SETUP': {
          // Get TOTP secret for authenticator app
          const tokenResult = await cognito.send(
            new AssociateSoftwareTokenCommand({
              Session: authResult.Session,
            })
          );
          return respond.ok({
            challenge: 'MFA_SETUP',
            session: tokenResult.Session,
            secretCode: tokenResult.SecretCode,
            message: 'Scan QR code in Google/Microsoft Authenticator',
          });
        }

        case 'SOFTWARE_TOKEN_MFA':
          return respond.ok({
            challenge: 'SOFTWARE_TOKEN_MFA',
            session: authResult.Session,
            message: 'Enter 6-digit code from Authenticator app',
          });

        default:
          return respond.ok({
            challenge: authResult.ChallengeName,
            session: authResult.Session,
          });
      }
    }

    // Success — return tokens
    const tokens = authResult.AuthenticationResult;
    if (!tokens) {
      return respond.serverError('Authentication failed — no tokens returned');
    }

    return respond.ok({
      accessToken: tokens.AccessToken,
      refreshToken: tokens.RefreshToken,
      idToken: tokens.IdToken,
      expiresIn: tokens.ExpiresIn,
    });
  } catch (err: any) {
    console.error('[AUTH/LOGIN]', err);
    if (err.name === 'NotAuthorizedException') {
      return respond.unauthorized('Invalid email or password');
    }
    if (err.name === 'UserNotFoundException') {
      return respond.unauthorized('Invalid email or password');
    }
    return respond.serverError('Login failed');
  }
};
