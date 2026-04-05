/**
 * POST /attendance/mark-mobile — Cognito auth (faculty app)
 *
 * Geofence check → anti-spoof → face search → mark attendance.
 * GPS coordinates stored with every mobile scan.
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { LocationClient, BatchEvaluateGeofencesCommand } from '@aws-sdk/client-location';
import { RekognitionClient, DetectFacesCommand, SearchFacesByImageCommand } from '@aws-sdk/client-rekognition';
import { respond, extractUser, getItem, putItem, queryItems, scanItems, uploadFile } from '../../lib';
import { TABLE_NAMES, BUCKET_NAMES, AWS_CONFIG, LIMITS } from '../../lib/constants';
import { getISTDate, getISTTime, getISTTimestamp, getISTHoursMinutes, isTimeBetween } from '../../lib/time';
import type { Student, SessionConfig, AttendanceRecord, AttendanceMarkResult } from '../../types/models';

const location = new LocationClient({ region: 'ap-south-1' });
const rekognition = new RekognitionClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const { image, latitude, longitude } = JSON.parse(event.body ?? '{}');

    if (!image || latitude == null || longitude == null) {
      return respond.badRequest('image, latitude, and longitude are required');
    }

    // Step 1: Geofence check
    const geoResult = await location.send(
      new BatchEvaluateGeofencesCommand({
        CollectionName: AWS_CONFIG.GEOFENCE_COLLECTION,
        DevicePositionUpdates: [{
          DeviceId: user.userId,
          Position: [longitude, latitude],
          SampleTime: new Date(),
        }],
      })
    );

    // If no geofence violations (device is OUTSIDE)
    const errors = geoResult.Errors ?? [];
    if (errors.length > 0) {
      return respond.ok({ status: 'OutOfZone', message: 'You are outside the allowed area' } as AttendanceMarkResult);
    }

    const imageBytes = Buffer.from(image, 'base64');

    // Step 2: Anti-spoofing
    const detectResult = await rekognition.send(
      new DetectFacesCommand({ Image: { Bytes: imageBytes }, Attributes: ['ALL'] })
    );
    const faces = detectResult.FaceDetails ?? [];
    if (faces.length === 0) return respond.ok({ status: 'Unknown', message: 'No face detected' } as AttendanceMarkResult);

    const face = faces[0];
    if (!face.EyesOpen?.Value || (face.EyesOpen?.Confidence ?? 0) < 80) {
      return respond.ok({ status: 'Spoofing', message: 'Liveness check failed' } as AttendanceMarkResult);
    }

    const emotions = face.Emotions ?? [];
    const dominant = emotions.reduce((a, b) => ((a.Confidence ?? 0) > (b.Confidence ?? 0) ? a : b), emotions[0]);

    // Step 3: Search face
    let searchResult;
    try {
      searchResult = await rekognition.send(
        new SearchFacesByImageCommand({
          CollectionId: AWS_CONFIG.COLLECTION_ID,
          Image: { Bytes: imageBytes },
          FaceMatchThreshold: LIMITS.FACE_CONFIDENCE_THRESHOLD,
          MaxFaces: 1,
        })
      );
    } catch {
      return respond.ok({ status: 'Unknown', message: 'Face not recognized' } as AttendanceMarkResult);
    }

    const matches = searchResult.FaceMatches ?? [];
    if (matches.length === 0) return respond.ok({ status: 'Unknown', message: 'Face not in database' } as AttendanceMarkResult);

    const [, studentId] = (matches[0].Face?.ExternalImageId ?? '').split('#');
    const student = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId });
    if (!student) return respond.ok({ status: 'Unknown', message: 'Student not found' } as AttendanceMarkResult);

    // Step 4: Session + duplicate check
    const { items: sessions } = await scanItems<SessionConfig>({ tableName: TABLE_NAMES.SESSIONS });
    const { hours, minutes } = getISTHoursMinutes();
    const currentTime = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
    const activeSession = sessions.find((s) => s.isActive && isTimeBetween(currentTime, s.startTime, s.endTime));
    if (!activeSession) return respond.ok({ status: 'Error', message: 'No active session' } as AttendanceMarkResult);

    const today = getISTDate();
    const { items: existing } = await queryItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      indexName: 'student-date-index',
      keyCondition: 'studentId = :sid AND #d = :date',
      expressionValues: { ':sid': studentId, ':date': today },
      expressionNames: { '#d': 'date' },
    });
    if (existing.find((r) => r.sessionType === activeSession.name)) {
      return respond.ok({ status: 'Already Marked', studentName: student.name, sessionName: activeSession.name } as AttendanceMarkResult);
    }

    // Step 5: Save
    const timeStr = getISTTime();
    const scanKey = `scans/mobile/${today}/${studentId}/${Date.now()}.jpg`;
    await uploadFile(BUCKET_NAMES.SCAN_IMAGES, scanKey, imageBytes, 'image/jpeg');

    await putItem(TABLE_NAMES.ATTENDANCE, {
      recordId: uuid(),
      studentId,
      sessionType: activeSession.name,
      date: today,
      time: timeStr,
      method: 'auto-mobile',
      markedBy: user.userId,
      confidence: matches[0].Similarity,
      scanImageKey: scanKey,
      emotion: dominant?.Type,
      emotionConfidence: dominant?.Confidence,
      latitude,
      longitude,
      createdAt: getISTTimestamp(),
    });

    return respond.ok({
      status: currentTime > activeSession.endTime ? 'Late' : 'Present',
      studentName: student.name,
      sessionName: activeSession.name,
      date: today,
      time: timeStr,
      emotion: dominant?.Type,
    } as AttendanceMarkResult);
  } catch (err: any) {
    console.error('[ATTENDANCE/MARK-MOBILE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Mobile attendance failed');
  }
};
