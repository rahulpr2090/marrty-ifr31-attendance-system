/**
 * API Gateway Construct — REST API
 *
 * Creates the REST API shell. Cognito authorizer and Lambda integrations
 * will be wired in Phase 2 when handlers are built.
 * Supports up to 20MB request payloads for image uploads.
 */

import { Construct } from 'constructs';
import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as cognito from 'aws-cdk-lib/aws-cognito';

interface ApiGatewayProps {
  userPool: cognito.UserPool;
}

export class ApiGatewayConstruct extends Construct {
  public readonly api: apigateway.RestApi;
  public readonly userPool: cognito.UserPool;

  constructor(scope: Construct, id: string, props: ApiGatewayProps) {
    super(scope, id);

    this.userPool = props.userPool;

    // ─── REST API ──────────────────────────────────────
    this.api = new apigateway.RestApi(this, 'MarrtyApi', {
      restApiName: 'marrty-api',
      description: 'Marrty IFR31 — Attendance System API',
      deployOptions: {
        stageName: 'api',
        throttlingBurstLimit: 50,
        throttlingRateLimit: 100,
      },
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: [
          'Content-Type',
          'Authorization',
          'x-api-key',
        ],
        maxAge: cdk.Duration.hours(1),
      },
      binaryMediaTypes: ['image/*', 'multipart/form-data'],
      minimumCompressionSize: 1024,
    });

    // Note: Cognito authorizer will be created when Lambda handlers
    // are wired in Phase 2 (Session 3). Authorizer needs at least one
    // method attached to synthesize properly.
  }
}
