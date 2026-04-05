/**
 * AWS Secrets Manager Client
 *
 * Fetches secrets at Lambda cold-start and caches them in memory.
 * NEVER hardcode API keys or credentials in source code.
 */

import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

const client = new SecretsManagerClient({ region: 'ap-south-1' });

// In-memory cache — survives across warm Lambda invocations
const secretCache = new Map<string, { value: string; expiresAt: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Get a secret value by name. Results are cached for 5 minutes.
 * @param secretName - The AWS Secrets Manager secret name (e.g., "marrty/api-keys")
 */
export async function getSecret(secretName: string): Promise<Record<string, string>> {
  const cached = secretCache.get(secretName);
  if (cached && Date.now() < cached.expiresAt) {
    return JSON.parse(cached.value);
  }

  const result = await client.send(
    new GetSecretValueCommand({ SecretId: secretName })
  );

  const secretString = result.SecretString;
  if (!secretString) {
    throw new Error(`Secret "${secretName}" has no string value`);
  }

  secretCache.set(secretName, {
    value: secretString,
    expiresAt: Date.now() + CACHE_TTL_MS,
  });

  return JSON.parse(secretString);
}
