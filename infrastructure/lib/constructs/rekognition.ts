/**
 * Rekognition Construct — Face Collection
 *
 * Uses a CloudFormation Custom Resource (Lambda-backed) to
 * create the Rekognition face collection since there's no
 * native CloudFormation resource for it.
 */

import { Construct } from 'constructs';
import * as cr from 'aws-cdk-lib/custom-resources';
import * as iam from 'aws-cdk-lib/aws-iam';

export class RekognitionConstruct extends Construct {
  public readonly collectionId: string;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.collectionId = 'marrty-faces';

    // ─── Custom Resource to create Rekognition collection
    new cr.AwsCustomResource(this, 'FaceCollection', {
      onCreate: {
        service: 'Rekognition',
        action: 'createCollection',
        parameters: { CollectionId: this.collectionId },
        physicalResourceId: cr.PhysicalResourceId.of(this.collectionId),
      },
      onDelete: {
        service: 'Rekognition',
        action: 'deleteCollection',
        parameters: { CollectionId: this.collectionId },
      },
      policy: cr.AwsCustomResourcePolicy.fromStatements([
        new iam.PolicyStatement({
          actions: [
            'rekognition:CreateCollection',
            'rekognition:DeleteCollection',
          ],
          resources: ['*'],
        }),
      ]),
    });
  }
}
