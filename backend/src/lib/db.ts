/**
 * DynamoDB Document Client — Singleton + Helper Functions
 *
 * All database operations go through these typed helpers.
 * Table names come from environment variables (set by CDK).
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
  ScanCommand,
  BatchWriteCommand,
  type QueryCommandInput,
  type ScanCommandInput,
} from '@aws-sdk/lib-dynamodb';

// Singleton client — reused across warm Lambda invocations
const rawClient = new DynamoDBClient({ region: 'ap-south-1' });
export const docClient = DynamoDBDocumentClient.from(rawClient, {
  marshallOptions: { removeUndefinedValues: true },
});

/** Put a single item */
export async function putItem(tableName: string, item: Record<string, unknown>) {
  await docClient.send(new PutCommand({ TableName: tableName, Item: item }));
}

/** Get a single item by primary key */
export async function getItem<T>(tableName: string, key: Record<string, string>): Promise<T | null> {
  const result = await docClient.send(new GetCommand({ TableName: tableName, Key: key }));
  return (result.Item as T) ?? null;
}

/** Query items using a key condition expression */
export async function queryItems<T>(params: {
  tableName: string;
  indexName?: string;
  keyCondition: string;
  expressionValues: Record<string, unknown>;
  expressionNames?: Record<string, string>;
  limit?: number;
  lastKey?: Record<string, unknown>;
  scanForward?: boolean;
}): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const input: QueryCommandInput = {
    TableName: params.tableName,
    IndexName: params.indexName,
    KeyConditionExpression: params.keyCondition,
    ExpressionAttributeValues: params.expressionValues,
    ExpressionAttributeNames: params.expressionNames,
    Limit: params.limit,
    ExclusiveStartKey: params.lastKey,
    ScanIndexForward: params.scanForward ?? true,
  };
  const result = await docClient.send(new QueryCommand(input));
  return {
    items: (result.Items as T[]) ?? [],
    lastKey: result.LastEvaluatedKey,
  };
}

/** Update an item with update expression */
export async function updateItem(params: {
  tableName: string;
  key: Record<string, string>;
  updateExpression: string;
  expressionValues: Record<string, unknown>;
  expressionNames?: Record<string, string>;
}) {
  await docClient.send(
    new UpdateCommand({
      TableName: params.tableName,
      Key: params.key,
      UpdateExpression: params.updateExpression,
      ExpressionAttributeValues: params.expressionValues,
      ExpressionAttributeNames: params.expressionNames,
    })
  );
}

/** Soft-delete or hard-delete an item */
export async function deleteItem(tableName: string, key: Record<string, string>) {
  await docClient.send(new DeleteCommand({ TableName: tableName, Key: key }));
}

/** Scan with optional filters (use sparingly — prefer queries) */
export async function scanItems<T>(params: {
  tableName: string;
  filterExpression?: string;
  expressionValues?: Record<string, unknown>;
  expressionNames?: Record<string, string>;
  limit?: number;
  lastKey?: Record<string, unknown>;
}): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const input: ScanCommandInput = {
    TableName: params.tableName,
    FilterExpression: params.filterExpression,
    ExpressionAttributeValues: params.expressionValues,
    ExpressionAttributeNames: params.expressionNames,
    Limit: params.limit,
    ExclusiveStartKey: params.lastKey,
  };
  const result = await docClient.send(new ScanCommand(input));
  return {
    items: (result.Items as T[]) ?? [],
    lastKey: result.LastEvaluatedKey,
  };
}

/** Batch write (up to 25 items per call) */
export async function batchWrite(tableName: string, items: Record<string, unknown>[]) {
  const BATCH_SIZE = 25;
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const batch = items.slice(i, i + BATCH_SIZE);
    await docClient.send(
      new BatchWriteCommand({
        RequestItems: {
          [tableName]: batch.map((item) => ({
            PutRequest: { Item: item },
          })),
        },
      })
    );
  }
}
