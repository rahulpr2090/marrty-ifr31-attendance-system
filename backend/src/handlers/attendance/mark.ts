/**
 * POST /attendance/mark — API Key auth (for ESP32 device)
 *
 * Full flow: anti-spoof → face search → session check → duplicate check → streak → save
 */

import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import {
  RekognitionClient,
  DetectFacesCommand,
  SearchFacesByImageCommand,
} from '@aws-sdk/client-rekognition';
import { respond, getItem, putItem, queryItems, scanItems, uploadFile } from '../../lib';
import { TABLE_NAMES, BUCKET_NAMES, AWS_CONFIG, LIMITS } from '../../lib/constants';
import { getISTDate, getISTTime, getISTTimestamp, getISTHoursMinutes, isTimeBetween } from '../../lib/time';
import type { Student, SessionConfig, AttendanceRecord, AttendanceMarkResult } from '../../types/models';

const rekognition = new RekognitionClient({ region: 'ap-south-1' });

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const { image, deviceId } = JSON.parse(event.body ?? '{}');
    if (!image) return respond.badRequest('image (base64) is required');

    const imageBytes = Buffer.from(image, 'base64');

    // Step 1: Anti-spoofing + emotion detection
    const detectResult = await rekognition.send(
      new DetectFacesCommand({ Image: { Bytes: imageBytes }, Attributes: ['ALL'] })
    );
    const faces = detectResult.FaceDetails ?? [];
    if (faces.length === 0) {
      return respond.ok({ status: 'Unknown', message: 'No face detected' } as AttendanceMarkResult);
    }

    const face = faces[0];

    // Liveness checks
    if ((face.EyesOpen?.Confidence ?? 0) < 80 || !face.EyesOpen?.Value) {
      return respond.ok({ status: 'Spoofing', message: 'Liveness check failed — eyes must be open' } as AttendanceMarkResult);
    }
    if ((face.Quality?.Brightness ?? 0) < 40 || (face.Quality?.Sharpness ?? 0) < 40) {
      return respond.ok({ status: 'Spoofing', message: 'Liveness check failed — image quality too low' } as AttendanceMarkResult);
    }
    if (Math.abs(face.Pose?.Yaw ?? 0) > 30 || Math.abs(face.Pose?.Pitch ?? 0) > 30) {
      return respond.ok({ status: 'Spoofing', message: 'Liveness check failed — look straight at camera' } as AttendanceMarkResult);
    }

    // Extract emotion
    const emotions = face.Emotions ?? [];
    const dominant = emotions.reduce((a, b) => ((a.Confidence ?? 0) > (b.Confidence ?? 0) ? a : b), emotions[0]);

    // Step 2: Search face
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
    if (matches.length === 0) {
      return respond.ok({ status: 'Unknown', message: 'Face not in database' } as AttendanceMarkResult);
    }

    const match = matches[0];
    const externalId = match.Face?.ExternalImageId ?? '';
    const [, studentId] = externalId.split('#');
    const confidence = match.Similarity ?? 0;

    // Get student
    const student = await getItem<Student>(TABLE_NAMES.STUDENTS, { studentId });
    if (!student) {
      return respond.ok({ status: 'Unknown', message: 'Student not found in database' } as AttendanceMarkResult);
    }

    // Step 3: Get active session
    const { items: sessions } = await scanItems<SessionConfig>({ tableName: TABLE_NAMES.SESSIONS });
    const { hours, minutes } = getISTHoursMinutes();
    const currentTime = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
    const activeSession = sessions.find((s) => s.isActive && isTimeBetween(currentTime, s.startTime, s.endTime));

    if (!activeSession) {
      return respond.ok({ status: 'Error', message: 'No active session', studentName: student.name } as AttendanceMarkResult);
    }

    // Step 4: Check already marked today
    const today = getISTDate();
    const { items: existing } = await queryItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      indexName: 'student-date-index',
      keyCondition: 'studentId = :sid AND #d = :date',
      expressionValues: { ':sid': studentId, ':date': today, ':sess': activeSession.name },
      expressionNames: { '#d': 'date' },
    });

    const alreadyMarked = existing.find((r) => r.sessionType === activeSession.name);
    if (alreadyMarked) {
      return respond.ok({
        status: 'Already Marked',
        studentName: student.name,
        sessionName: activeSession.name,
      } as AttendanceMarkResult);
    }

    // Step 5: Late check
    const isLate = currentTime > activeSession.endTime;

    // Step 6: Calculate streak
    let streak = 1;
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    // Simple streak: count consecutive days with attendance
    for (let i = 1; i <= 365; i++) {
      const checkDate = new Date();
      checkDate.setDate(checkDate.getDate() - i);
      const dateStr = checkDate.toISOString().split('T')[0];
      const { items: dayRecords } = await queryItems<AttendanceRecord>({
        tableName: TABLE_NAMES.ATTENDANCE,
        indexName: 'student-date-index',
        keyCondition: 'studentId = :sid AND #d = :date',
        expressionValues: { ':sid': studentId, ':date': dateStr },
        expressionNames: { '#d': 'date' },
        limit: 1,
      });
      if (dayRecords.length === 0) break;
      streak++;
      if (streak > 30) break; // Cap streak calculation
    }

    // Step 7: Save scan image
    const timeStr = getISTTime();
    const scanKey = `scans/${today}/${studentId}/${Date.now()}.jpg`;
    await uploadFile(BUCKET_NAMES.SCAN_IMAGES, scanKey, imageBytes, 'image/jpeg');

    // Step 8: Create attendance record
    const record: AttendanceRecord = {
      recordId: uuid(),
      studentId,
      sessionType: activeSession.name as any,
      date: today,
      time: timeStr,
      method: 'auto',
      deviceId,
      confidence,
      scanImageKey: scanKey,
      emotion: dominant?.Type as any,
      emotionConfidence: dominant?.Confidence,
      streak,
      createdAt: getISTTimestamp(),
    };

    await putItem(TABLE_NAMES.ATTENDANCE, record);

    return respond.ok({
      status: isLate ? 'Late' : 'Present',
      studentName: student.name,
      sessionName: activeSession.name,
      date: today,
      time: timeStr,
      streak,
      emotion: dominant?.Type,
      confidence,
    } as AttendanceMarkResult);
  } catch (err) {
    console.error('[ATTENDANCE/MARK]', err);
    return respond.serverError('Attendance marking failed');
  }
};
