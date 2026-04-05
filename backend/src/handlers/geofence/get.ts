/**
 * GET /geofence — HOD only
 *
 * Get current geofence polygon from Amazon Location Service.
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { LocationClient, GetGeofenceCommand } from '@aws-sdk/client-location';
import { respond, requireRole } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const location = new LocationClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    requireRole(event, ['hod']);

    const result = await location.send(
      new GetGeofenceCommand({
        CollectionName: AWS_CONFIG.GEOFENCE_COLLECTION,
        GeofenceId: 'department-zone',
      })
    );

    const polygon = result.Geometry?.Polygon?.[0] ?? [];

    return respond.ok({
      geofenceId: 'department-zone',
      polygon: polygon.map(([lng, lat]) => [lat, lng]),
      status: result.Status,
    });
  } catch (err: any) {
    console.error('[GEOFENCE/GET]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    if (err.name === 'ResourceNotFoundException') {
      return respond.ok({ geofenceId: 'department-zone', polygon: [], status: 'NOT_CONFIGURED' });
    }
    return respond.serverError('Failed to get geofence');
  }
};
