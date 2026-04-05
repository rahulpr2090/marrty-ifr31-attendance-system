/**
 * PUT /geofence — HOD only
 *
 * Update geofence with polygon or circle (center + radius).
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { LocationClient, PutGeofenceCommand } from '@aws-sdk/client-location';
import { respond, requireRole, logAction } from '../../lib';
import { updateGeofenceSchema } from '../../lib/validators';
import { AWS_CONFIG } from '../../lib/constants';

const location = new LocationClient({ region: 'ap-south-1' });

/** Generate circle polygon approximation (32 points) */
function circleToPolygon(lat: number, lng: number, radiusM: number): number[][] {
  const points: number[][] = [];
  const R = 6371000; // Earth radius in meters
  for (let i = 0; i < 32; i++) {
    const angle = (i / 32) * 2 * Math.PI;
    const dLat = (radiusM * Math.cos(angle)) / R;
    const dLng = (radiusM * Math.sin(angle)) / (R * Math.cos((lat * Math.PI) / 180));
    points.push([lng + (dLng * 180) / Math.PI, lat + (dLat * 180) / Math.PI]);
  }
  points.push(points[0]); // Close the ring
  return points;
}

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = requireRole(event, ['hod']);
    const parsed = updateGeofenceSchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) return respond.badRequest('Validation failed', parsed.error.flatten());

    const data = parsed.data;
    let polygon: number[][];

    if ('polygon' in data) {
      // Convert [lat, lng] to [lng, lat] for AWS + close ring
      polygon = data.polygon.map(([lat, lng]) => [lng, lat]);
      if (polygon[0][0] !== polygon[polygon.length - 1][0] || polygon[0][1] !== polygon[polygon.length - 1][1]) {
        polygon.push(polygon[0]);
      }
    } else {
      polygon = circleToPolygon(data.center.lat, data.center.lng, data.radiusMeters);
    }

    await location.send(
      new PutGeofenceCommand({
        CollectionName: AWS_CONFIG.GEOFENCE_COLLECTION,
        GeofenceId: 'department-zone',
        Geometry: { Polygon: [polygon] },
      })
    );

    await logAction({ actorId: user.userId, action: 'UPDATE_GEOFENCE', targetEntity: 'geofence', targetId: 'department-zone' });
    return respond.ok({ message: 'Geofence updated', polygon: polygon.map(([lng, lat]) => [lat, lng]) });
  } catch (err: any) {
    console.error('[GEOFENCE/UPDATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Failed to update geofence');
  }
};
