/**
 * Cognito Construct — User Pool, MFA, Groups, HOD User
 *
 * MFA is REQUIRED (TOTP via Google/Microsoft Authenticator).
 * Access tokens expire in 12 hours — forced re-login.
 */

import { Construct } from 'constructs';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as cdk from 'aws-cdk-lib';

export class CognitoConstruct extends Construct {
  public readonly userPool: cognito.UserPool;
  public readonly userPoolClient: cognito.UserPoolClient;
  public readonly hodGroup: cognito.CfnUserPoolGroup;
  public readonly lecturerGroup: cognito.CfnUserPoolGroup;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    // ─── User Pool ─────────────────────────────────────
    this.userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: 'marrty-users',
      selfSignUpEnabled: false,
      signInAliases: { email: true },
      autoVerify: { email: true },
      passwordPolicy: {
        minLength: 10,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
      mfa: cognito.Mfa.REQUIRED,
      mfaSecondFactor: {
        sms: false,
        otp: true, // TOTP — Google/Microsoft Authenticator
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // ─── App Client (12-hour tokens) ───────────────────
    this.userPoolClient = this.userPool.addClient('AppClient', {
      userPoolClientName: 'marrty-client',
      authFlows: {
        userPassword: true,
        userSrp: true,
      },
      accessTokenValidity: cdk.Duration.hours(12),
      idTokenValidity: cdk.Duration.hours(12),
      refreshTokenValidity: cdk.Duration.days(7),
      preventUserExistenceErrors: true,
      generateSecret: false,
    });

    // ─── Groups ────────────────────────────────────────
    this.hodGroup = new cognito.CfnUserPoolGroup(this, 'HodGroup', {
      userPoolId: this.userPool.userPoolId,
      groupName: 'hod',
      description: 'Head of Department — full access',
      precedence: 0,
    });

    this.lecturerGroup = new cognito.CfnUserPoolGroup(this, 'LecturerGroup', {
      userPoolId: this.userPool.userPoolId,
      groupName: 'lecturer',
      description: 'Lecturer — limited access per permissions',
      precedence: 1,
    });

    // ─── HOD User (first admin) ────────────────────────
    const hodUser = new cognito.CfnUserPoolUser(this, 'HodUser', {
      userPoolId: this.userPool.userPoolId,
      username: 'hod@if31.marrty.in',
      userAttributes: [
        { name: 'email', value: 'hod@if31.marrty.in' },
        { name: 'email_verified', value: 'true' },
      ],
      desiredDeliveryMediums: ['EMAIL'],
    });

    // Add HOD to hod group
    const hodGroupMembership = new cognito.CfnUserPoolUserToGroupAttachment(
      this, 'HodGroupMembership', {
        userPoolId: this.userPool.userPoolId,
        username: 'hod@if31.marrty.in',
        groupName: 'hod',
      },
    );
    hodGroupMembership.addDependency(hodUser);
    hodGroupMembership.addDependency(this.hodGroup);
  }
}
