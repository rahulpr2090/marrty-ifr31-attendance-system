/**
 * POST /reports/generate — Excel or PDF report
 */
import type { APIGatewayProxyHandler } from 'aws-lambda';
import { v4 as uuid } from 'uuid';
import { respond, extractUser, scanItems, uploadFile, getPresignedUrl, logAction } from '../../lib';
import { generateReportSchema } from '../../lib/validators';
import { TABLE_NAMES, BUCKET_NAMES } from '../../lib/constants';
import type { AttendanceRecord, Student } from '../../types/models';

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const user = extractUser(event);
    const parsed = generateReportSchema.safeParse(JSON.parse(event.body ?? '{}'));
    if (!parsed.success) return respond.badRequest('Validation failed', parsed.error.flatten());

    const { type, dateFrom, dateTo, batchYear, semester, studentId } = parsed.data;

    // Fetch attendance records
    const filters: string[] = ['#d BETWEEN :df AND :dt'];
    const values: Record<string, unknown> = { ':df': dateFrom, ':dt': dateTo };
    const names: Record<string, string> = { '#d': 'date' };

    if (studentId) { filters.push('studentId = :sid'); values[':sid'] = studentId; }

    const { items: records } = await scanItems<AttendanceRecord>({
      tableName: TABLE_NAMES.ATTENDANCE,
      filterExpression: filters.join(' AND '),
      expressionValues: values,
      expressionNames: names,
    });

    // Fetch student info
    const studentIds = [...new Set(records.map((r) => r.studentId))];
    const studentMap: Record<string, Student> = {};
    for (const sid of studentIds) {
      const { items } = await scanItems<Student>({
        tableName: TABLE_NAMES.STUDENTS,
        filterExpression: 'studentId = :sid',
        expressionValues: { ':sid': sid },
        limit: 1,
      });
      if (items[0]) studentMap[sid] = items[0];
    }

    let buffer: Buffer;
    let contentType: string;
    let ext: string;

    if (type === 'excel') {
      // Generate CSV (lightweight — no ExcelJS dependency needed)
      const header = 'Date,Name,Roll No,PNR,Session,Time,Method,Emotion\n';
      const rows = records.map((r) => {
        const s = studentMap[r.studentId];
        return `${r.date},${s?.name ?? 'Unknown'},${s?.rollNo ?? ''},${s?.pnr ?? ''},${r.sessionType},${r.time},${r.method},${r.emotion ?? ''}`;
      }).join('\n');
      buffer = Buffer.from(header + rows, 'utf-8');
      contentType = 'text/csv';
      ext = 'csv';
    } else {
      // Generate simple text report (lightweight — no PDFKit needed)
      const lines = [
        '╔═══════════════════════════════════════════════════╗',
        '║      DEPT OF COMPUTER ENGINEERING — HGPC         ║',
        '║      Attendance Report                            ║',
        `║      ${dateFrom} to ${dateTo}                     ║`,
        '╚═══════════════════════════════════════════════════╝',
        '',
        `Total Records: ${records.length}`,
        `Students: ${studentIds.length}`,
        '',
        'Date       | Name              | Roll  | Session   | Time     | Method',
        '-'.repeat(80),
        ...records.map((r) => {
          const s = studentMap[r.studentId];
          return `${r.date} | ${(s?.name ?? 'Unknown').padEnd(17)} | ${(s?.rollNo ?? '').padEnd(5)} | ${r.sessionType.padEnd(9)} | ${r.time} | ${r.method}`;
        }),
      ];
      buffer = Buffer.from(lines.join('\n'), 'utf-8');
      contentType = 'text/plain';
      ext = 'txt';
    }

    // Upload to S3
    const fileName = `report_${dateFrom}_${dateTo}_${uuid().slice(0, 8)}.${ext}`;
    const s3Key = `reports/${fileName}`;
    await uploadFile(BUCKET_NAMES.EXPORTS, s3Key, buffer, contentType);

    // Generate download URL
    const downloadUrl = await getPresignedUrl(BUCKET_NAMES.EXPORTS, s3Key, 3600);

    await logAction({ actorId: user.userId, action: 'GENERATE_REPORT', targetEntity: 'report', targetId: fileName });

    return respond.ok({ downloadUrl, fileName, recordCount: records.length, studentCount: studentIds.length });
  } catch (err: any) {
    console.error('[REPORT/GENERATE]', err);
    if (err.statusCode === 403) return respond.forbidden(err.message);
    return respond.serverError('Report generation failed');
  }
};
