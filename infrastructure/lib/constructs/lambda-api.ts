/**
 * Lambda + API Gateway Integration Construct
 *
 * Creates all Lambda functions, wires them to API Gateway
 * with proper auth (Cognito vs API Key), and grants IAM permissions.
 *
 * Dev: rahulpr2000 | RAHUL PR | Marrty LLC
 */

import { Construct } from 'constructs';
import * as cdk from 'aws-cdk-lib';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as path from 'path';

interface LambdaApiProps {
  api: apigateway.RestApi;
  userPool: cognito.UserPool;
  tables: {
    students: dynamodb.Table;
    faculty: dynamodb.Table;
    attendance: dynamodb.Table;
    sessions: dynamodb.Table;
    audit: dynamodb.Table;
    bugs: dynamodb.Table;
  };
  buckets: {
    faceImages: s3.Bucket;
    scanImages: s3.Bucket;
    profiles: s3.Bucket;
    exports: s3.Bucket;
  };
  userPoolClientId: string;
  collectionId: string;
  geofenceCollectionName: string;
  trackerName: string;
}

export class LambdaApiConstruct extends Construct {
  constructor(scope: Construct, id: string, props: LambdaApiProps) {
    super(scope, id);

    const distPath = path.resolve(__dirname, '../../../backend/dist/handlers');

    // ─── Shared Env Vars ────────────────────────────────
    const commonEnv: Record<string, string> = {
      STUDENTS_TABLE: props.tables.students.tableName,
      FACULTY_TABLE: props.tables.faculty.tableName,
      ATTENDANCE_TABLE: props.tables.attendance.tableName,
      SESSIONS_TABLE: props.tables.sessions.tableName,
      AUDIT_TABLE: props.tables.audit.tableName,
      BUGS_TABLE: props.tables.bugs.tableName,
      FACE_IMAGES_BUCKET: props.buckets.faceImages.bucketName,
      SCAN_IMAGES_BUCKET: props.buckets.scanImages.bucketName,
      PROFILES_BUCKET: props.buckets.profiles.bucketName,
      EXPORTS_BUCKET: props.buckets.exports.bucketName,
      USER_POOL_ID: props.userPool.userPoolId,
      CLIENT_ID: props.userPoolClientId,
      COLLECTION_ID: props.collectionId,
      GEOFENCE_COLLECTION: props.geofenceCollectionName,
      TRACKER_NAME: props.trackerName,
      SHARE_TABLE: 'marrty-shared-reports',
    };

    // Helper to create Lambda
    // esbuild outputs files named by source (e.g. auth/login.js), not index.js
    // LogGroup creation is disabled to stay under CloudFormation 500-resource limit
    const createLambda = (name: string, handlerDir: string, overrides?: { timeout?: cdk.Duration; memorySize?: number; environment?: Record<string, string> }) => {
      const handlerFile = handlerDir.split('/').pop()!; // "login" from "auth/login"
      const fn = new lambda.Function(this, name, {
        runtime: lambda.Runtime.NODEJS_20_X,
        timeout: overrides?.timeout ?? cdk.Duration.seconds(15),
        memorySize: overrides?.memorySize ?? 256,
        functionName: `marrty-${name}`,
        handler: `${handlerFile}.handler`,
        code: lambda.Code.fromAsset(path.join(distPath, handlerDir.split('/')[0])),
        environment: { ...commonEnv, ...overrides?.environment },
      });
      // Remove the auto-generated LogGroup to save CloudFormation resources
      fn.node.tryRemoveChild('LogGroup');
      return fn;
    };

    // ─── Cognito Authorizer ─────────────────────────────
    const cognitoAuth = new apigateway.CognitoUserPoolsAuthorizer(this, 'CognitoAuth', {
      cognitoUserPools: [props.userPool],
      identitySource: 'method.request.header.Authorization',
    });

    const cognitoMethodOpts: apigateway.MethodOptions = {
      authorizer: cognitoAuth,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    };

    // ─── API Key + Usage Plan ───────────────────────────
    const apiKey = props.api.addApiKey('DeviceApiKey', {
      apiKeyName: 'marrty-device-key',
      description: 'API key for ESP32 device authentication',
    });

    const usagePlan = props.api.addUsagePlan('DeviceUsagePlan', {
      name: 'device-plan',
      throttle: { rateLimit: 50, burstLimit: 20 },
      quota: { limit: 5000, period: apigateway.Period.DAY },
    });

    usagePlan.addApiKey(apiKey);
    usagePlan.addApiStage({ stage: props.api.deploymentStage });

    const apiKeyMethodOpts: apigateway.MethodOptions = {
      apiKeyRequired: true,
    };

    const noAuth: apigateway.MethodOptions = {
      authorizationType: apigateway.AuthorizationType.NONE,
    };

    // ─── Grant helpers ──────────────────────────────────
    const grantAllTables = (fn: lambda.Function) => {
      Object.values(props.tables).forEach((t) => t.grantReadWriteData(fn));
    };

    const grantAllBuckets = (fn: lambda.Function) => {
      Object.values(props.buckets).forEach((b) => b.grantReadWrite(fn));
    };

    const grantCognito = (fn: lambda.Function) => {
      fn.addToRolePolicy(new iam.PolicyStatement({
        actions: [
          'cognito-idp:AdminInitiateAuth',
          'cognito-idp:AdminRespondToAuthChallenge',
          'cognito-idp:AdminCreateUser',
          'cognito-idp:AdminDeleteUser',
          'cognito-idp:AdminDisableUser',
          'cognito-idp:AdminAddUserToGroup',
          'cognito-idp:AdminSetUserPassword',
          'cognito-idp:ListUsersInGroup',
          'cognito-idp:AssociateSoftwareToken',
          'cognito-idp:VerifySoftwareToken',
          'cognito-idp:ChangePassword',
        ],
        resources: [props.userPool.userPoolArn],
      }));
    };

    const grantRekognition = (fn: lambda.Function) => {
      fn.addToRolePolicy(new iam.PolicyStatement({
        actions: [
          'rekognition:DetectFaces',
          'rekognition:IndexFaces',
          'rekognition:SearchFacesByImage',
          'rekognition:DeleteFaces',
        ],
        resources: ['*'],
      }));
    };

    const grantLocation = (fn: lambda.Function) => {
      fn.addToRolePolicy(new iam.PolicyStatement({
        actions: [
          'geo:GetGeofence',
          'geo:PutGeofence',
          'geo:BatchEvaluateGeofences',
        ],
        resources: ['*'],
      }));
    };

    // ═════════════════════════════════════════════════════
    //  AUTH HANDLERS
    // ═════════════════════════════════════════════════════

    const authRes = props.api.root.addResource('auth');

    // POST /auth/login (public)
    const loginFn = createLambda('auth-login', 'auth/login');
    grantCognito(loginFn);
    authRes.addResource('login').addMethod('POST', new apigateway.LambdaIntegration(loginFn), noAuth);

    // POST /auth/verify-mfa (public)
    const verifyMfaFn = createLambda('auth-verify-mfa', 'auth/verify-mfa');
    grantCognito(verifyMfaFn);
    authRes.addResource('verify-mfa').addMethod('POST', new apigateway.LambdaIntegration(verifyMfaFn), noAuth);

    // POST /auth/change-password (public)
    const changePwdFn = createLambda('auth-change-password', 'auth/change-password');
    grantCognito(changePwdFn);
    authRes.addResource('change-password').addMethod('POST', new apigateway.LambdaIntegration(changePwdFn), noAuth);

    // GET /auth/me
    const meFn = createLambda('auth-me', 'auth/me');
    authRes.addResource('me').addMethod('GET', new apigateway.LambdaIntegration(meFn), cognitoMethodOpts);

    // /auth/sub-admins
    const subAdminsRes = authRes.addResource('sub-admins');

    const createSubAdminFn = createLambda('auth-create-sub-admin', 'auth/create-sub-admin');
    grantCognito(createSubAdminFn); grantAllTables(createSubAdminFn);
    subAdminsRes.addMethod('POST', new apigateway.LambdaIntegration(createSubAdminFn), cognitoMethodOpts);

    const listSubAdminsFn = createLambda('auth-list-sub-admins', 'auth/list-sub-admins');
    grantCognito(listSubAdminsFn);
    subAdminsRes.addMethod('GET', new apigateway.LambdaIntegration(listSubAdminsFn), cognitoMethodOpts);

    // /auth/sub-admins/{userId}
    const subAdminIdRes = subAdminsRes.addResource('{userId}');

    const resetPwdFn = createLambda('auth-reset-password', 'auth/reset-password');
    grantCognito(resetPwdFn); grantAllTables(resetPwdFn);
    subAdminIdRes.addResource('reset-password').addMethod('PUT', new apigateway.LambdaIntegration(resetPwdFn), cognitoMethodOpts);

    const deleteSubAdminFn = createLambda('auth-delete-sub-admin', 'auth/delete-sub-admin');
    grantCognito(deleteSubAdminFn); grantAllTables(deleteSubAdminFn);
    subAdminIdRes.addMethod('DELETE', new apigateway.LambdaIntegration(deleteSubAdminFn), cognitoMethodOpts);

    // ═════════════════════════════════════════════════════
    //  SESSION HANDLERS
    // ═════════════════════════════════════════════════════

    const sessionsRes = props.api.root.addResource('sessions');

    const initSessionsFn = createLambda('session-init', 'session/init-sessions');
    grantAllTables(initSessionsFn);
    sessionsRes.addResource('init').addMethod('POST', new apigateway.LambdaIntegration(initSessionsFn), cognitoMethodOpts);

    const listSessionsFn = createLambda('session-list', 'session/list-sessions');
    grantAllTables(listSessionsFn);
    sessionsRes.addMethod('GET', new apigateway.LambdaIntegration(listSessionsFn), cognitoMethodOpts);

    const getActiveFn = createLambda('session-get-active', 'session/get-active');
    grantAllTables(getActiveFn);
    sessionsRes.addResource('active').addMethod('GET', new apigateway.LambdaIntegration(getActiveFn), cognitoMethodOpts);

    const updateSessionFn = createLambda('session-update', 'session/update-session');
    grantAllTables(updateSessionFn);
    sessionsRes.addResource('{sessionId}').addMethod('PUT', new apigateway.LambdaIntegration(updateSessionFn), cognitoMethodOpts);

    // ═════════════════════════════════════════════════════
    //  STUDENT HANDLERS
    // ═════════════════════════════════════════════════════

    const studentsRes = props.api.root.addResource('students');

    const createStudentFn = createLambda('student-create', 'student/create');
    grantAllTables(createStudentFn);
    studentsRes.addMethod('POST', new apigateway.LambdaIntegration(createStudentFn), cognitoMethodOpts);

    const listStudentsFn = createLambda('student-list', 'student/list');
    grantAllTables(listStudentsFn);
    studentsRes.addMethod('GET', new apigateway.LambdaIntegration(listStudentsFn), cognitoMethodOpts);

    const studentIdRes = studentsRes.addResource('{studentId}');

    const getStudentFn = createLambda('student-get', 'student/get');
    grantAllTables(getStudentFn); grantAllBuckets(getStudentFn);
    studentIdRes.addMethod('GET', new apigateway.LambdaIntegration(getStudentFn), cognitoMethodOpts);

    const updateStudentFn = createLambda('student-update', 'student/update');
    grantAllTables(updateStudentFn);
    studentIdRes.addMethod('PUT', new apigateway.LambdaIntegration(updateStudentFn), cognitoMethodOpts);

    const deleteStudentFn = createLambda('student-delete', 'student/delete');
    grantAllTables(deleteStudentFn);
    studentIdRes.addMethod('DELETE', new apigateway.LambdaIntegration(deleteStudentFn), cognitoMethodOpts);

    // Bulk operations
    const semShiftFn = createLambda('student-semester-shift', 'student/semester-shift');
    grantAllTables(semShiftFn);
    studentsRes.addResource('semester-shift').addMethod('POST', new apigateway.LambdaIntegration(semShiftFn), cognitoMethodOpts);

    const markPassoutFn = createLambda('student-mark-passout', 'student/mark-passout');
    grantAllTables(markPassoutFn); grantRekognition(markPassoutFn);
    studentsRes.addResource('mark-passout').addMethod('POST', new apigateway.LambdaIntegration(markPassoutFn), cognitoMethodOpts);

    const bulkImportFn = createLambda('student-bulk-import', 'student/bulk-import', { timeout: cdk.Duration.seconds(30) });
    grantAllTables(bulkImportFn);
    studentsRes.addResource('bulk-import').addMethod('POST', new apigateway.LambdaIntegration(bulkImportFn), cognitoMethodOpts);

    // ═════════════════════════════════════════════════════
    //  FACULTY HANDLERS
    // ═════════════════════════════════════════════════════

    const facultyRes = props.api.root.addResource('faculty');

    const createFacultyFn = createLambda('faculty-create', 'faculty/create');
    grantAllTables(createFacultyFn);
    facultyRes.addMethod('POST', new apigateway.LambdaIntegration(createFacultyFn), cognitoMethodOpts);

    const listFacultyFn = createLambda('faculty-list', 'faculty/list');
    grantAllTables(listFacultyFn);
    facultyRes.addMethod('GET', new apigateway.LambdaIntegration(listFacultyFn), cognitoMethodOpts);

    const facultyIdRes = facultyRes.addResource('{facultyId}');

    const getFacultyFn = createLambda('faculty-get', 'faculty/get');
    grantAllTables(getFacultyFn); grantAllBuckets(getFacultyFn);
    facultyIdRes.addMethod('GET', new apigateway.LambdaIntegration(getFacultyFn), cognitoMethodOpts);

    const updateFacultyFn = createLambda('faculty-update', 'faculty/update');
    grantAllTables(updateFacultyFn);
    facultyIdRes.addMethod('PUT', new apigateway.LambdaIntegration(updateFacultyFn), cognitoMethodOpts);

    const deleteFacultyFn = createLambda('faculty-delete', 'faculty/delete');
    grantAllTables(deleteFacultyFn);
    facultyIdRes.addMethod('DELETE', new apigateway.LambdaIntegration(deleteFacultyFn), cognitoMethodOpts);

    // ═════════════════════════════════════════════════════
    //  FACE HANDLERS
    // ═════════════════════════════════════════════════════

    const faceRes = props.api.root.addResource('face');

    // POST /face/enroll/{entityType}/{entityId}
    const enrollFaceFn = createLambda('face-enroll', 'face/enroll', { memorySize: 512 });
    grantAllTables(enrollFaceFn); grantAllBuckets(enrollFaceFn); grantRekognition(enrollFaceFn);
    faceRes.addResource('enroll').addResource('{entityType}').addResource('{entityId}')
      .addMethod('POST', new apigateway.LambdaIntegration(enrollFaceFn), cognitoMethodOpts);

    // DELETE /face/{entityType}/{entityId}/{faceIndex}
    const removeFaceFn = createLambda('face-remove', 'face/remove');
    grantAllTables(removeFaceFn); grantAllBuckets(removeFaceFn); grantRekognition(removeFaceFn);
    const faceEntityRes = faceRes.addResource('{entityType}').addResource('{entityId}');
    faceEntityRes.addResource('{faceIndex}').addMethod('DELETE', new apigateway.LambdaIntegration(removeFaceFn), cognitoMethodOpts);

    // GET /face/{entityType}/{entityId} — get images
    const getImagesFn = createLambda('face-get-images', 'face/get-images');
    grantAllTables(getImagesFn); grantAllBuckets(getImagesFn);
    faceEntityRes.addMethod('GET', new apigateway.LambdaIntegration(getImagesFn), cognitoMethodOpts);

    // POST /face/search — API Key auth (device)
    const searchFaceFn = createLambda('face-search', 'face/search', { memorySize: 512 });
    grantAllTables(searchFaceFn); grantRekognition(searchFaceFn);
    faceRes.addResource('search').addMethod('POST', new apigateway.LambdaIntegration(searchFaceFn), apiKeyMethodOpts);

    // ═════════════════════════════════════════════════════
    //  ATTENDANCE HANDLERS
    // ═════════════════════════════════════════════════════

    const attendanceRes = props.api.root.addResource('attendance');

    // POST /attendance/mark — API Key (device)
    const markFn = createLambda('attendance-mark', 'attendance/mark', { timeout: cdk.Duration.seconds(25), memorySize: 512 });
    grantAllTables(markFn); grantAllBuckets(markFn); grantRekognition(markFn);
    attendanceRes.addResource('mark').addMethod('POST', new apigateway.LambdaIntegration(markFn), apiKeyMethodOpts);

    // POST /attendance/mark-mobile — Cognito (faculty)
    const markMobileFn = createLambda('attendance-mark-mobile', 'attendance/mark-mobile', { timeout: cdk.Duration.seconds(25), memorySize: 512 });
    grantAllTables(markMobileFn); grantAllBuckets(markMobileFn); grantRekognition(markMobileFn); grantLocation(markMobileFn);
    attendanceRes.addResource('mark-mobile').addMethod('POST', new apigateway.LambdaIntegration(markMobileFn), cognitoMethodOpts);

    // POST /attendance/manual
    const manualFn = createLambda('attendance-manual', 'attendance/manual');
    grantAllTables(manualFn);
    attendanceRes.addResource('manual').addMethod('POST', new apigateway.LambdaIntegration(manualFn), cognitoMethodOpts);

    // GET /attendance/records
    const recordsFn = createLambda('attendance-records', 'attendance/records');
    grantAllTables(recordsFn);
    attendanceRes.addResource('records').addMethod('GET', new apigateway.LambdaIntegration(recordsFn), cognitoMethodOpts);

    // GET /attendance/today
    const todayFn = createLambda('attendance-today', 'attendance/today');
    grantAllTables(todayFn);
    attendanceRes.addResource('today').addMethod('GET', new apigateway.LambdaIntegration(todayFn), cognitoMethodOpts);

    // GET /attendance/defaulters
    const defaultersFn = createLambda('attendance-defaulters', 'attendance/defaulters', { timeout: cdk.Duration.seconds(30) });
    grantAllTables(defaultersFn);
    attendanceRes.addResource('defaulters').addMethod('GET', new apigateway.LambdaIntegration(defaultersFn), cognitoMethodOpts);

    // GET /attendance/streaks
    const streaksFn = createLambda('attendance-streaks', 'attendance/streaks', { timeout: cdk.Duration.seconds(30) });
    grantAllTables(streaksFn);
    attendanceRes.addResource('streaks').addMethod('GET', new apigateway.LambdaIntegration(streaksFn), cognitoMethodOpts);

    // GET /attendance/anomalies
    const anomaliesFn = createLambda('attendance-anomalies', 'attendance/anomalies', { timeout: cdk.Duration.seconds(30) });
    grantAllTables(anomaliesFn);
    attendanceRes.addResource('anomalies').addMethod('GET', new apigateway.LambdaIntegration(anomaliesFn), cognitoMethodOpts);

    // GET /attendance/digest
    const digestFn = createLambda('attendance-weekly-digest', 'attendance/weekly-digest', { timeout: cdk.Duration.seconds(30) });
    grantAllTables(digestFn);
    attendanceRes.addResource('digest').addMethod('GET', new apigateway.LambdaIntegration(digestFn), cognitoMethodOpts);

    // /attendance/student/{studentId}/...
    const attStudentRes = attendanceRes.addResource('student').addResource('{studentId}');

    const historyFn = createLambda('attendance-student-history', 'attendance/student-history');
    grantAllTables(historyFn);
    attStudentRes.addResource('history').addMethod('GET', new apigateway.LambdaIntegration(historyFn), cognitoMethodOpts);

    const percentageFn = createLambda('attendance-student-percentage', 'attendance/student-percentage');
    grantAllTables(percentageFn);
    attStudentRes.addResource('percentage').addMethod('GET', new apigateway.LambdaIntegration(percentageFn), cognitoMethodOpts);

    const moodFn = createLambda('attendance-mood-trends', 'attendance/mood-trends');
    grantAllTables(moodFn);
    attStudentRes.addResource('mood').addMethod('GET', new apigateway.LambdaIntegration(moodFn), cognitoMethodOpts);

    // ═════════════════════════════════════════════════════
    //  GEOFENCE HANDLERS
    // ═════════════════════════════════════════════════════

    const geofenceRes = props.api.root.addResource('geofence');

    const getGeofenceFn = createLambda('geofence-get', 'geofence/get');
    grantLocation(getGeofenceFn);
    geofenceRes.addMethod('GET', new apigateway.LambdaIntegration(getGeofenceFn), cognitoMethodOpts);

    const updateGeofenceFn = createLambda('geofence-update', 'geofence/update');
    grantLocation(updateGeofenceFn); grantAllTables(updateGeofenceFn);
    geofenceRes.addMethod('PUT', new apigateway.LambdaIntegration(updateGeofenceFn), cognitoMethodOpts);

    const checkGeofenceFn = createLambda('geofence-check', 'geofence/check');
    grantLocation(checkGeofenceFn);
    geofenceRes.addResource('check').addMethod('POST', new apigateway.LambdaIntegration(checkGeofenceFn), cognitoMethodOpts);

    // ═════════════════════════════════════════════════════
    //  REPORT HANDLERS
    // ═════════════════════════════════════════════════════

    const reportsRes = props.api.root.addResource('reports');

    const generateReportFn = createLambda('report-generate', 'report/generate', { timeout: cdk.Duration.seconds(30), memorySize: 512 });
    grantAllTables(generateReportFn); grantAllBuckets(generateReportFn);
    reportsRes.addResource('generate').addMethod('POST', new apigateway.LambdaIntegration(generateReportFn), cognitoMethodOpts);

    const shareReportFn = createLambda('report-share', 'report/share');
    grantAllTables(shareReportFn);
    reportsRes.addResource('share').addMethod('POST', new apigateway.LambdaIntegration(shareReportFn), cognitoMethodOpts);

    // GET /reports/public/{shareToken} — NO auth
    const publicDownloadFn = createLambda('report-public-download', 'report/public-download');
    grantAllTables(publicDownloadFn); grantAllBuckets(publicDownloadFn);
    reportsRes.addResource('public').addResource('{shareToken}')
      .addMethod('GET', new apigateway.LambdaIntegration(publicDownloadFn), noAuth);

    // ═════════════════════════════════════════════════════
    //  AUDIT HANDLER
    // ═════════════════════════════════════════════════════

    const auditRes = props.api.root.addResource('audit');
    const auditLogsFn = createLambda('audit-logs', 'audit/logs');
    grantAllTables(auditLogsFn);
    auditRes.addResource('logs').addMethod('GET', new apigateway.LambdaIntegration(auditLogsFn), cognitoMethodOpts);

    // ═════════════════════════════════════════════════════
    //  BUG REPORT HANDLERS
    // ═════════════════════════════════════════════════════

    const bugsRes = props.api.root.addResource('bugs');

    const createBugFn = createLambda('bugs-create', 'bugs/create');
    grantAllTables(createBugFn);
    bugsRes.addMethod('POST', new apigateway.LambdaIntegration(createBugFn), cognitoMethodOpts);

    const listBugsFn = createLambda('bugs-list', 'bugs/list');
    grantAllTables(listBugsFn);
    bugsRes.addMethod('GET', new apigateway.LambdaIntegration(listBugsFn), cognitoMethodOpts);

    const updateBugFn = createLambda('bugs-update', 'bugs/update');
    grantAllTables(updateBugFn);
    bugsRes.addResource('{reportId}').addMethod('PUT', new apigateway.LambdaIntegration(updateBugFn), cognitoMethodOpts);

    // ─── Output the generated API Key ───────────────────
    new cdk.CfnOutput(scope, 'DeviceApiKeyId', {
      value: apiKey.keyId,
      description: 'API Key ID for the ESP32 device (retrieve value from AWS Console)',
    });
  }
}
