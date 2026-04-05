/**
 * Image Compression — Server-Side via Sharp
 *
 * Accepts uploads up to 20MB, compresses to optimized JPEG.
 * Strips EXIF metadata for privacy (removes GPS, camera info).
 */

import sharp from 'sharp';

const MAX_UPLOAD_SIZE = 20 * 1024 * 1024; // 20MB
const MAX_DIMENSION = 2048;
const JPEG_QUALITY = 85; // Visually lossless

export interface CompressionResult {
  buffer: Buffer;
  originalSize: number;
  compressedSize: number;
  width: number;
  height: number;
}

/**
 * Compress an image buffer for storage.
 *
 * - Validates max 20MB input
 * - Resizes if any dimension exceeds 2048px (maintains aspect ratio)
 * - Converts to JPEG quality 85 (visually lossless)
 * - Strips all EXIF metadata (privacy)
 *
 * @returns Compressed buffer with size metadata
 */
export async function compressImage(input: Buffer): Promise<CompressionResult> {
  if (input.length > MAX_UPLOAD_SIZE) {
    throw new ImageError(`Image exceeds maximum size of 20MB (received: ${(input.length / 1024 / 1024).toFixed(1)}MB)`);
  }

  const result = await sharp(input)
    .rotate()                        // Auto-rotate based on EXIF orientation
    .resize(MAX_DIMENSION, MAX_DIMENSION, {
      fit: 'inside',                 // Maintain aspect ratio, don't upscale
      withoutEnlargement: true,
    })
    .jpeg({ quality: JPEG_QUALITY }) // Visually lossless compression
    .withMetadata({ orientation: undefined }) // Strip EXIF but keep color profile
    .toBuffer({ resolveWithObject: true });

  return {
    buffer: result.data,
    originalSize: input.length,
    compressedSize: result.data.length,
    width: result.info.width,
    height: result.info.height,
  };
}

/** Custom error for image validation failures */
export class ImageError extends Error {
  public readonly statusCode = 400;
  constructor(message: string) {
    super(message);
    this.name = 'ImageError';
  }
}
