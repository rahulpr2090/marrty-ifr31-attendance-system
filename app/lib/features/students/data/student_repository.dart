// lib/features/students/data/student_repository.dart
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/student_models.dart';

class StudentRepository {
  final _api = ApiClient.instance;

  Future<List<Student>> list({
    String? batchYear,
    String? semester,
    String? status,
    String? search,
    String? lastKey,
  }) async {
    final params = <String, dynamic>{};
    if (batchYear != null) params['batchYear'] = batchYear;
    if (semester  != null) params['semester']  = semester;
    if (status    != null) params['status']    = status;
    if (search    != null) params['search']    = search;
    if (lastKey   != null) params['lastKey']   = lastKey;

    final res = await _api.get(ApiConstants.students, params: params);
    final items = res['students'] as List? ?? [];
    return items.map((e) => Student.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Student> get(String studentId) async {
    final res = await _api.get('${ApiConstants.students}/$studentId');
    return Student.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<Student> create(Map<String, dynamic> body) async {
    final res = await _api.post(ApiConstants.students, data: body);
    return Student.fromJson(Map<String, dynamic>.from(res['student'] as Map));
  }

  Future<Student> update(String id, Map<String, dynamic> body) async {
    final res = await _api.put('${ApiConstants.students}/$id', data: body);
    return Student.fromJson(Map<String, dynamic>.from(res['student'] as Map));
  }

  Future<void> delete(String id) async {
    await _api.delete('${ApiConstants.students}/$id');
  }

  Future<List<AttendanceRecord>> getHistory(String studentId) async {
    final res = await _api.get('/attendance/student/$studentId/history');
    final items = res['records'] as List? ?? [];
    return items.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getPercentage(String studentId) async {
    final res = await _api.get('/attendance/student/$studentId/percentage');
    return Map<String, dynamic>.from(res as Map);
  }
}
