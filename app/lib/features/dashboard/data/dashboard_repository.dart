// lib/features/dashboard/data/dashboard_repository.dart
// Fetches today's stats, streaks, and anomalies from API.
// Returns safe defaults on error to prevent blank screens.
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/dashboard_models.dart';

class DashboardRepository {
  final _api = ApiClient.instance;

  /// Fetch today's attendance snapshot. Returns empty defaults on error.
  Future<TodayStats> getTodayStats() async {
    try {
      final res = await _api.get(ApiConstants.attendanceToday);
      return TodayStats.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (_) {
      return const TodayStats(
        totalStudents: 0,
        presentCount: 0,
        attendancePercent: 0,
        defaulterCount: 0,
        sessions: [],
        recentScans: [],
      );
    }
  }

  /// Fetch top attendance streaks. Returns empty list on error.
  Future<List<StreakEntry>> getStreaks() async {
    try {
      final res = await _api.get(ApiConstants.attendanceStreaks);
      final list = (res['streaks'] as List? ?? []);
      return list.asMap().entries
          .map((e) => StreakEntry.fromJson(e.value as Map<String, dynamic>, e.key + 1))
          .take(5)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch attendance anomalies. Returns empty list on error.
  Future<List<AnomalyAlert>> getAnomalies() async {
    try {
      final res = await _api.get(ApiConstants.attendanceAnomalies);
      final list = (res['anomalies'] as List? ?? []);
      return list
          .map((e) => AnomalyAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
