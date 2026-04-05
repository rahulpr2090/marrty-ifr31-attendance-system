#!/usr/bin/env node
/**
 * Marrty IFR31 — CDK App Entry Point
 * Region: ap-south-1 (Mumbai)
 * Developer: rahulpr2000 | RAHUL PR | Marrty LLC
 */

import * as cdk from 'aws-cdk-lib';
import { MarrtyIFR31Stack } from '../lib/marrty-stack';

const app = new cdk.App();

new MarrtyIFR31Stack(app, 'MarrtyIFR31Stack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: 'ap-south-1',
  },
  description: 'Marrty IFR31 — Smart Face Recognition Attendance System',
});
