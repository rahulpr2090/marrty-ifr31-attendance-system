// lib/features/dashboard/domain/dashboard_models.dart
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

class TodayStats {
  final int totalStudents;
  final int presentCount;
  final double attendancePercent;
  final String? activeSession;
  final int defaulterCount;
  final List<SessionSummary> sessions;
  final List<RecentScan> recentScans;

  const TodayStats({
    required this.totalStudents,
    required this.presentCount,
    required this.attendancePercent,
    this.activeSession,
    required this.defaulterCount,
    required this.sessions,
    required this.recentScans,
  });

  factory TodayStats.fromJson(Map<String, dynamic> j) => TodayStats(
    totalStudents:     j['totalStudents']     as int? ?? 0,
    presentCount:      j['presentCount']      as int? ?? 0,
    attendancePercent: (j['attendancePercent'] as num?)?.toDouble() ?? 0,
    activeSession:     j['activeSession']     as String?,
    defaulterCount:    j['defaulterCount']    as int? ?? 0,
    sessions:  (j['sessions']   as List? ?? []).map((e) => SessionSummary.fromJson(e as Map<String, dynamic>)).toList(),
    recentScans: (j['recentScans'] as List? ?? []).map((e) => RecentScan.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class SessionSummary {
  final String name;
  final int present;
  final int absent;
  final int late;
  final bool isActive;

  const SessionSummary({
    required this.name,
    required this.present,
    required this.absent,
    required this.late,
    required this.isActive,
  });

  int get total => present + absent + late;
  double get percent => total == 0 ? 0 : present / total;

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
    name:     j['sessionName'] as String? ?? '',
    present:  j['present']    as int? ?? 0,
    absent:   j['absent']     as int? ?? 0,
    late:     j['late']       as int? ?? 0,
    isActive: j['isActive']   as bool? ?? false,
  );
}

class RecentScan {
  final String studentName;
  final String rollNo;
  final String? profileUrl;
  final String session;
  final String time;
  final String status;
  final String? emotion;

  const RecentScan({
    required this.studentName,
    required this.rollNo,
    this.profileUrl,
    required this.session,
    required this.time,
    required this.status,
    this.emotion,
  });

  factory RecentScan.fromJson(Map<String, dynamic> j) => RecentScan(
    studentName: j['studentName'] as String? ?? '',
    rollNo:      j['rollNo']      as String? ?? '',
    profileUrl:  j['profileUrl']  as String?,
    session:     j['sessionName'] as String? ?? '',
    time:        j['time']        as String? ?? '',
    status:      j['status']      as String? ?? '',
    emotion:     j['emotion']     as String?,
  );
}

class StreakEntry {
  final int rank;
  final String studentName;
  final String? profileUrl;
  final int streak;

  const StreakEntry({
    required this.rank,
    required this.studentName,
    this.profileUrl,
    required this.streak,
  });

  factory StreakEntry.fromJson(Map<String, dynamic> j, int rank) => StreakEntry(
    rank:        rank,
    studentName: j['studentName'] as String? ?? '',
    profileUrl:  j['profileUrl']  as String?,
    streak:      j['streak']      as int? ?? 0,
  );
}

class AnomalyAlert {
  final String studentName;
  final String pattern;
  final String severity; // "high" | "medium"
  final String studentId;

  const AnomalyAlert({
    required this.studentName,
    required this.pattern,
    required this.severity,
    required this.studentId,
  });

  factory AnomalyAlert.fromJson(Map<String, dynamic> j) => AnomalyAlert(
    studentName: j['studentName'] as String? ?? '',
    pattern:     j['pattern']     as String? ?? '',
    severity:    j['severity']    as String? ?? 'medium',
    studentId:   j['studentId']   as String? ?? '',
  );
}
