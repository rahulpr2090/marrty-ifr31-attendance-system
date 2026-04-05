/**
 * S3 Construct — All Buckets with Encryption & Lifecycle
 *
 * All buckets are private with block-public-access.
 * Scan images: 180-day retention. Exports: 30-day retention.
 */

import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as kms from 'aws-cdk-lib/aws-kms';
import * as cdk from 'aws-cdk-lib';

interface S3Props {
  encryptionKey: kms.Key;
}

export class S3Construct extends Construct {
  public readonly faceImagesBucket: s3.Bucket;
  public readonly scanImagesBucket: s3.Bucket;
  public readonly profilesBucket: s3.Bucket;
  public readonly exportsBucket: s3.Bucket;

  constructor(scope: Construct, id: string, props: S3Props) {
    super(scope, id);

    const commonProps: Partial<s3.BucketProps> = {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.KMS,
      encryptionKey: props.encryptionKey,
      enforceSSL: true,
      versioned: false,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    };

    const corsRules: s3.CorsRule[] = [{
      allowedMethods: [s3.HttpMethods.GET, s3.HttpMethods.PUT, s3.HttpMethods.POST],
      allowedOrigins: ['*'],
      allowedHeaders: ['*'],
      maxAge: 3600,
    }];

    // ─── Face Images (enrollment photos) ───────────────
    this.faceImagesBucket = new s3.Bucket(this, 'FaceImagesBucket', {
      ...commonProps,
      bucketName: `marrty-face-images-${cdk.Aws.ACCOUNT_ID}`,
      cors: corsRules,
    });

    // ─── Scan Images (device + mobile, 180-day retention)
    this.scanImagesBucket = new s3.Bucket(this, 'ScanImagesBucket', {
      ...commonProps,
      bucketName: `marrty-scan-images-${cdk.Aws.ACCOUNT_ID}`,
      lifecycleRules: [{
        id: 'delete-scans-after-180-days',
        expiration: cdk.Duration.days(180),
        enabled: true,
      }],
    });

    // ─── Profile Photos ────────────────────────────────
    this.profilesBucket = new s3.Bucket(this, 'ProfilesBucket', {
      ...commonProps,
      bucketName: `marrty-profiles-${cdk.Aws.ACCOUNT_ID}`,
      cors: corsRules,
    });

    // ─── Report Exports (30-day retention) ─────────────
    this.exportsBucket = new s3.Bucket(this, 'ExportsBucket', {
      ...commonProps,
      bucketName: `marrty-exports-${cdk.Aws.ACCOUNT_ID}`,
      lifecycleRules: [{
        id: 'delete-exports-after-30-days',
        expiration: cdk.Duration.days(30),
        enabled: true,
      }],
    });
  }
}
