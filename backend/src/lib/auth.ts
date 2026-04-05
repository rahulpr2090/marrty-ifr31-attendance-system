/**
 * Auth Middleware — JWT Parsing & Role Enforcement
 *
 * Extracts user context from API Gateway Cognito authorizer claims.
 * Provides role-based access control helpers.
 */

import type { APIGatewayProxyEvent } from 'aws-lambda';
import type { UserContext, UserRole } from '../types/models';

/**
 * Extract authenticated user context from the API Gateway event.
 * Cognito authorizer injects claims into the request context.
 */
export function extractUser(event: APIGatewayProxyEvent): UserContext {
  const claims = event.requestContext.authorizer?.claims;
  if (!claims) {
    throw new AuthError('No authorization claims found');
  }

  return {
    userId: claims.sub as string,
    email: claims.email as string,
    role: (claims['cognito:groups'] as string)?.includes('hod') ? 'hod' : 'lecturer',
    groups: ((claims['cognito:groups'] as string) ?? '').split(',').filter(Boolean),
  };
}

/**
 * Enforce that the current user belongs to one of the allowed roles.
 * Throws 403 if the user doesn't have permission.
 */
export function requireRole(event: APIGatewayProxyEvent, allowedRoles: UserRole[]): UserContext {
  const user = extractUser(event);
  if (!allowedRoles.includes(user.role)) {
    throw new AuthError(`Role "${user.role}" is not authorized. Required: ${allowedRoles.join(', ')}`);
  }
  return user;
}

/** Custom auth error for consistent handling */
export class AuthError extends Error {
  public readonly statusCode = 403;
  constructor(message: string) {
    super(message);
    this.name = 'AuthError';
  }
}
