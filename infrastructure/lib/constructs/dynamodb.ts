/**
 * DynamoDB Construct — All Tables with GSIs
 *
 * All tables use PAY_PER_REQUEST billing and KMS encryption.
 * Table design follows single-table-per-entity pattern for clarity.
 */

import { Construct } from 'constructs';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as kms from 'aws-cdk-lib/aws-kms';
import * as cdk from 'aws-cdk-lib';

interface DynamoDBProps {
  encryptionKey: kms.Key;
}

export class DynamoDBConstruct extends Construct {
  public readonly studentsTable: dynamodb.Table;
  public readonly facultyTable: dynamodb.Table;
  public readonly attendanceTable: dynamodb.Table;
  public readonly sessionsTable: dynamodb.Table;
  public readonly auditTable: dynamodb.Table;
  public readonly bugsTable: dynamodb.Table;

  constructor(scope: Construct, id: string, props: DynamoDBProps) {
    super(scope, id);

    const commonProps = {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.CUSTOMER_MANAGED,
      encryptionKey: props.encryptionKey,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecovery: true,
    };

    // ─── Students Table ────────────────────────────────
    this.studentsTable = new dynamodb.Table(this, 'StudentsTable', {
      ...commonProps,
      tableName: 'marrty-students',
      partitionKey: { name: 'studentId', type: dynamodb.AttributeType.STRING },
    });
    this.studentsTable.addGlobalSecondaryIndex({
      indexName: 'rollNo-index',
      partitionKey: { name: 'rollNo', type: dynamodb.AttributeType.STRING },
    });
    this.studentsTable.addGlobalSecondaryIndex({
      indexName: 'batch-sem-index',
      partitionKey: { name: 'batchYear', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'semester', type: dynamodb.AttributeType.STRING },
    });
    this.studentsTable.addGlobalSecondaryIndex({
      indexName: 'pnr-index',
      partitionKey: { name: 'pnr', type: dynamodb.AttributeType.STRING },
    });

    // ─── Faculty Table ─────────────────────────────────
    this.facultyTable = new dynamodb.Table(this, 'FacultyTable', {
      ...commonProps,
      tableName: 'marrty-faculty',
      partitionKey: { name: 'facultyId', type: dynamodb.AttributeType.STRING },
    });
    this.facultyTable.addGlobalSecondaryIndex({
      indexName: 'email-index',
      partitionKey: { name: 'email', type: dynamodb.AttributeType.STRING },
    });

    // ─── Attendance Table ──────────────────────────────
    this.attendanceTable = new dynamodb.Table(this, 'AttendanceTable', {
      ...commonProps,
      tableName: 'marrty-attendance',
      partitionKey: { name: 'recordId', type: dynamodb.AttributeType.STRING },
    });
    this.attendanceTable.addGlobalSecondaryIndex({
      indexName: 'student-date-index',
      partitionKey: { name: 'studentId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'date', type: dynamodb.AttributeType.STRING },
    });
    this.attendanceTable.addGlobalSecondaryIndex({
      indexName: 'session-date-index',
      partitionKey: { name: 'sessionType', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'date', type: dynamodb.AttributeType.STRING },
    });

    // ─── Sessions Table ────────────────────────────────
    this.sessionsTable = new dynamodb.Table(this, 'SessionsTable', {
      ...commonProps,
      tableName: 'marrty-sessions',
      partitionKey: { name: 'sessionId', type: dynamodb.AttributeType.STRING },
    });

    // ─── Audit Table ───────────────────────────────────
    this.auditTable = new dynamodb.Table(this, 'AuditTable', {
      ...commonProps,
      tableName: 'marrty-audit',
      partitionKey: { name: 'logId', type: dynamodb.AttributeType.STRING },
    });
    this.auditTable.addGlobalSecondaryIndex({
      indexName: 'actor-time-index',
      partitionKey: { name: 'actorId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'timestamp', type: dynamodb.AttributeType.STRING },
    });

    // ─── Bugs Table ────────────────────────────────────
    this.bugsTable = new dynamodb.Table(this, 'BugsTable', {
      ...commonProps,
      tableName: 'marrty-bugs',
      partitionKey: { name: 'reportId', type: dynamodb.AttributeType.STRING },
    });
    this.bugsTable.addGlobalSecondaryIndex({
      indexName: 'status-index',
      partitionKey: { name: 'status', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'createdAt', type: dynamodb.AttributeType.STRING },
    });
  }
}
