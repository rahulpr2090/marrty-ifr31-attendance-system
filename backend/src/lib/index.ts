/**
 * Barrel export for all shared library modules.
 * Import from '@lib' or '../lib' in handlers.
 */

export { success, error, respond } from './response';
export { putItem, getItem, queryItems, updateItem, deleteItem, scanItems, batchWrite } from './db';
export { uploadFile, getPresignedUrl, deleteFile } from './s3';
export { getSecret } from './secrets';
export { extractUser, requireRole, AuthError } from './auth';
export { logAction } from './audit';
// Note: image.ts is NOT re-exported here because it depends on 'sharp' (native binary).
// Handlers needing compressImage must import it directly: import { compressImage } from '../../lib/image';
export { getISTNow, getISTTimestamp, getISTDate, getISTTime, getISTHoursMinutes, isTimeBetween, formatISTDate } from './time';
export { TABLE_NAMES, BUCKET_NAMES, AWS_CONFIG, LIMITS, BATCH_YEARS, SEMESTERS, SESSION_TYPES, SEMESTER_ORDER, SEMESTER_DEMOTION } from './constants';
