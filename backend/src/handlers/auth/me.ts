/**
 * GET /auth/me — Cognito authorized
 *
 * Returns the authenticated user's profile from JWT claims.
 * Includes name from Cognito 'name' or 'custom:name' claim.
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { respond, extractUser } from '../../lib';
import { AuthError } from '../../lib/auth';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const claims = event.requestContext.authorizer?.claims ?? {};

    // Extract name from various Cognito claim sources
    const name = (claims.name as string)
      ?? (claims['custom:name'] as string)
      ?? (claims.given_name as string)
      ?? user.email.split('@')[0]; // Fallback: use email prefix

    return respond.ok({
      userId: user.userId,
      email: user.email,
      name,
      role: user.role,
      groups: user.groups,
    });
  } catch (err) {
    if (err instanceof AuthError) {
      return respond.forbidden(err.message);
    }
    console.error('[AUTH/ME]', err);
    return respond.serverError('Failed to get user info');
  }
};
