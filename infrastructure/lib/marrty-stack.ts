/**
 * Marrty IFR31 — Main CDK Stack
 *
 * Orchestrates all AWS resources in a single stack.
 * Each resource group is organized into its own construct for maintainability.
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { CognitoConstruct } from './constructs/cognito';
import { DynamoDBConstruct } from './constructs/dynamodb';
import { S3Construct } from './constructs/s3';
import { SecurityConstruct } from './constructs/security';
import { ApiGatewayConstruct } from './constructs/api-gateway';
import { RekognitionConstruct } from './constructs/rekognition';
import { LocationConstruct } from './constructs/location';
import { LambdaApiConstruct } from './constructs/lambda-api';

export class MarrtyIFR31Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ─── Security (KMS + Secrets Manager) ──────────────
    const security = new SecurityConstruct(this, 'Security');

    // ─── Cognito (Auth + MFA) ──────────────────────────
    const cognito = new CognitoConstruct(this, 'Cognito');

    // ─── DynamoDB (All Tables) ─────────────────────────
    const dynamodb = new DynamoDBConstruct(this, 'DynamoDB', {
      encryptionKey: security.encryptionKey,
    });

    // ─── S3 (All Buckets) ──────────────────────────────
    const s3 = new S3Construct(this, 'S3', {
      encryptionKey: security.encryptionKey,
    });

    // ─── Rekognition (Face Collection) ─────────────────
    const rekognition = new RekognitionConstruct(this, 'Rekognition');

    // ─── API Gateway (REST API) ────────────────────────
    const apiGateway = new ApiGatewayConstruct(this, 'ApiGateway', {
      userPool: cognito.userPool,
    });

    // ─── Amazon Location Service (Geofencing) ──────────
    const location = new LocationConstruct(this, 'Location');

    // ─── Lambda Functions + API Routes (Phase 2) ───────
    new LambdaApiConstruct(this, 'LambdaApi', {
      api: apiGateway.api,
      userPool: cognito.userPool,
      userPoolClientId: cognito.userPoolClient.userPoolClientId,
      collectionId: rekognition.collectionId,
      geofenceCollectionName: location.geofenceCollectionName,
      trackerName: location.trackerName,
      tables: {
        students: dynamodb.studentsTable,
        faculty: dynamodb.facultyTable,
        attendance: dynamodb.attendanceTable,
        sessions: dynamodb.sessionsTable,
        audit: dynamodb.auditTable,
        bugs: dynamodb.bugsTable,
      },
      buckets: {
        faceImages: s3.faceImagesBucket,
        scanImages: s3.scanImagesBucket,
        profiles: s3.profilesBucket,
        exports: s3.exportsBucket,
      },
    });

    // ─── Stack Outputs ─────────────────────────────────
    this.exportOutputs(cognito, dynamodb, s3, apiGateway, security, location);
  }

  private exportOutputs(
    cognito: CognitoConstruct,
    dynamodb: DynamoDBConstruct,
    s3: S3Construct,
    apiGateway: ApiGatewayConstruct,
    security: SecurityConstruct,
    location: LocationConstruct,
  ) {
    // Cognito
    new cdk.CfnOutput(this, 'UserPoolId', { value: cognito.userPool.userPoolId });
    new cdk.CfnOutput(this, 'UserPoolClientId', { value: cognito.userPoolClient.userPoolClientId });

    // DynamoDB
    new cdk.CfnOutput(this, 'StudentsTable', { value: dynamodb.studentsTable.tableName });
    new cdk.CfnOutput(this, 'FacultyTable', { value: dynamodb.facultyTable.tableName });
    new cdk.CfnOutput(this, 'AttendanceTable', { value: dynamodb.attendanceTable.tableName });
    new cdk.CfnOutput(this, 'SessionsTable', { value: dynamodb.sessionsTable.tableName });
    new cdk.CfnOutput(this, 'AuditTable', { value: dynamodb.auditTable.tableName });
    new cdk.CfnOutput(this, 'BugsTable', { value: dynamodb.bugsTable.tableName });

    // S3
    new cdk.CfnOutput(this, 'FaceImagesBucket', { value: s3.faceImagesBucket.bucketName });
    new cdk.CfnOutput(this, 'ScanImagesBucket', { value: s3.scanImagesBucket.bucketName });
    new cdk.CfnOutput(this, 'ProfilesBucket', { value: s3.profilesBucket.bucketName });
    new cdk.CfnOutput(this, 'ExportsBucket', { value: s3.exportsBucket.bucketName });

    // API Gateway
    new cdk.CfnOutput(this, 'ApiUrl', { value: apiGateway.api.url });
    new cdk.CfnOutput(this, 'ApiId', { value: apiGateway.api.restApiId });

    // Security
    new cdk.CfnOutput(this, 'KmsKeyArn', { value: security.encryptionKey.keyArn });
    new cdk.CfnOutput(this, 'ApiKeysSecretArn', { value: security.apiKeysSecret.secretArn });
    new cdk.CfnOutput(this, 'ConfigSecretArn', { value: security.configSecret.secretArn });

    // Location
    new cdk.CfnOutput(this, 'TrackerName', { value: location.trackerName });
    new cdk.CfnOutput(this, 'GeofenceCollectionName', { value: location.geofenceCollectionName });
  }
}
