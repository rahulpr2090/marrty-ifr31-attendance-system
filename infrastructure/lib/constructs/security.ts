/**
 * Security Construct — KMS + Secrets Manager
 *
 * Creates the encryption key and secrets for the entire system.
 * No sensitive values are ever hardcoded in source code.
 */

import { Construct } from 'constructs';
import * as kms from 'aws-cdk-lib/aws-kms';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as cdk from 'aws-cdk-lib';

export class SecurityConstruct extends Construct {
  /** KMS key for encrypting DynamoDB, S3, and Secrets Manager */
  public readonly encryptionKey: kms.Key;
  /** Secret for device API keys */
  public readonly apiKeysSecret: secretsmanager.Secret;
  /** Secret for application configuration */
  public readonly configSecret: secretsmanager.Secret;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    // ─── KMS Encryption Key ────────────────────────────
    this.encryptionKey = new kms.Key(this, 'EncryptionKey', {
      alias: 'marrty-encryption-key',
      description: 'Marrty IFR31 — Encryption key for all data at rest',
      enableKeyRotation: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // ─── Secrets Manager: API Keys ─────────────────────
    this.apiKeysSecret = new secretsmanager.Secret(this, 'ApiKeysSecret', {
      secretName: 'marrty/api-keys',
      description: 'Device API keys for ESP32S3 authentication',
      encryptionKey: this.encryptionKey,
      generateSecretString: {
        secretStringTemplate: JSON.stringify({ deviceApiKey: '' }),
        generateStringKey: 'generatedKey',
        excludeCharacters: '"@/\\',
        passwordLength: 32,
      },
    });

    // ─── Secrets Manager: Config ───────────────────────
    this.configSecret = new secretsmanager.Secret(this, 'ConfigSecret', {
      secretName: 'marrty/config',
      description: 'Application configuration — Rekognition collection, bucket names, etc.',
      encryptionKey: this.encryptionKey,
      secretStringValue: cdk.SecretValue.unsafePlainText(JSON.stringify({
        collectionId: 'marrty-faces',
        region: 'ap-south-1',
      })),
    });
  }
}
