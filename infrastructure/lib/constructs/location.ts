/**
 * Amazon Location Service Construct — Geofencing
 *
 * Creates a tracker and geofence collection for GPS-based
 * attendance zone enforcement. HOD configures the zone via the app.
 */

import { Construct } from 'constructs';
import * as cdk from 'aws-cdk-lib';
import * as location from 'aws-cdk-lib/aws-location';

export class LocationConstruct extends Construct {
  public readonly trackerName: string;
  public readonly geofenceCollectionName: string;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.trackerName = 'marrty-tracker';
    this.geofenceCollectionName = 'marrty-geofences';

    // ─── Geofence Collection ───────────────────────────
    const geofenceCollection = new location.CfnGeofenceCollection(this, 'GeofenceCollection', {
      collectionName: this.geofenceCollectionName,
      description: 'Marrty IFR31 — Department attendance zone geofences',
    });

    // ─── Tracker ───────────────────────────────────────
    const tracker = new location.CfnTracker(this, 'Tracker', {
      trackerName: this.trackerName,
      description: 'Marrty IFR31 — Faculty device position tracker',
      positionFiltering: 'DistanceBased',
    });

    // ─── Associate Tracker with Geofence Collection ────
    new location.CfnTrackerConsumer(this, 'TrackerConsumer', {
      trackerName: tracker.trackerName,
      consumerArn: geofenceCollection.attrArn,
    });
  }
}
