/**
 * Standardized API Response Builder
 *
 * All Lambda handlers return responses through these helpers
 * to ensure consistent format and CORS headers.
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization,x-api-key',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Content-Type': 'application/json',
};

/** Build a success response */
export function success<T>(statusCode: number, body: T) {
  return {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify(body),
  };
}

/** Build an error response */
export function error(statusCode: number, message: string, details?: unknown) {
  return {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      error: true,
      message,
      ...(details ? { details } : {}),
    }),
  };
}

/** Pre-built common responses */
export const respond = {
  ok: <T>(body: T) => success(200, body),
  created: <T>(body: T) => success(201, body),
  noContent: () => success(204, null),
  badRequest: (msg: string, details?: unknown) => error(400, msg, details),
  unauthorized: (msg = 'Unauthorized') => error(401, msg),
  forbidden: (msg = 'Forbidden') => error(403, msg),
  notFound: (msg = 'Not found') => error(404, msg),
  conflict: (msg: string) => error(409, msg),
  gone: (msg = 'Resource expired') => error(410, msg),
  serverError: (msg = 'Internal server error') => error(500, msg),
};
