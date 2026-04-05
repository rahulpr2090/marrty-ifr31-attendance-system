/**
 * POST /geofence/check — verify if a point is inside the geofence
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { LocationClient, BatchEvaluateGeofencesCommand } from '@aws-sdk/client-location';
import { respond } from '../../lib';
import { AWS_CONFIG } from '../../lib/constants';

const location = new LocationClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const { latitude, longitude } = JSON.parse(event.body ?? '{}');
    if (latitude == null || longitude == null) {
      return respond.badRequest('latitude and longitude are required');
    }

    const result = await location.send(
      new BatchEvaluateGeofencesCommand({
        CollectionName: AWS_CONFIG.GEOFENCE_COLLECTION,
        DevicePositionUpdates: [{
          DeviceId: 'check-device',
          Position: [longitude, latitude],
          SampleTime: new Date(),
        }],
      })
    );

    const errors = result.Errors ?? [];
    const inside = errors.length === 0;

    return respond.ok({ inside, geofenceName: 'department-zone', latitude, longitude });
  } catch (err) {
    console.error('[GEOFENCE/CHECK]', err);
    return respond.serverError('Geofence check failed');
  }
};
