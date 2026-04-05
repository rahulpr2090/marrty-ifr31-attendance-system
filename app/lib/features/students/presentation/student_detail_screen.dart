// lib/features/students/presentation/student_detail_screen.dart
// Student detail: profile, face enrollment, attendance heatmap, mood chart
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/student_models.dart';
import '../data/student_repository.dart';
import '../../../core/constants/app_constants.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final Student student;
  const StudentDetailScreen({super.key, required this.student});
  @override ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _repo = StudentRepository();
  final _picker = ImagePicker();
  late Student _student;
  List<AttendanceRecord> _history = [];
  Map<String, dynamic> _stats = {};
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _student = widget.student;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final [history, stats] = await Future.wait([
        _repo.getHistory(_student.studentId),
        _repo.getPercentage(_student.studentId),
      ]);
      if (mounted) setState(() {
        _history = history as List<AttendanceRecord>;
        _stats   = stats as Map<String, dynamic>;
        _loadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _enrollFace() async {
    final picked = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Face Photo'),
        content: const Text('Max 20 MB. Server compresses automatically.'),
        actions: [
          TextButton.icon(onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt), label: const Text('Camera')),
          TextButton.icon(onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library), label: const Text('Gallery')),
        ],
      ),
    );

    if (picked == null) return;
    final file = await _picker.pickImage(source: picked, imageQuality: 90);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image exceeds 20 MB limit'), backgroundColor: AppColors.error));
      return;
    }

    try {
      // Send as multipart — simplified for now
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading...'), duration: Duration(seconds: 1)));

      await ApiClient.instance.post(ApiConstants.faceEnroll, data: {
        'studentId': _student.studentId,
        'imageBase64': _encodeBase64(bytes),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Face enrolled successfully'), backgroundColor: AppColors.success));

      setState(() => _student = Student(
        studentId: _student.studentId, name: _student.name,
        rollNo: _student.rollNo, pnr: _student.pnr,
        batchYear: _student.batchYear, semester: _student.semester,
        gender: _student.gender, status: _student.status,
        faceEnrolled: true, enrolledFaces: _student.enrolledFaces + 1,
        streak: _student.streak, createdAt: _student.createdAt,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: AppColors.error));
    }
  }

  String _encodeBase64(List<int> bytes) {
    // Dart has base64 in dart:convert
    final base64 = StringBuffer();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    for (int i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      base64.write(chars[(b0 >> 2) & 0x3F]);
      base64.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      base64.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      base64.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return base64.toString();
  }

  // Build heatmap dataset from attendance history
  Map<DateTime, int> _heatmapData() {
    final map = <DateTime, int>{};
    for (final r in _history) {
      try {
        final d = DateTime.parse(r.date);
        final key = DateTime(d.year, d.month, d.day);
        map[key] = (map[key] ?? 0) + (r.status == 'Present' ? 1 : 0);
      } catch (_) {}
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_stats['percentage'] as num?)?.toDouble() ?? 0;
    final present = _stats['present'] as int? ?? 0;
    final late    = _stats['late']    as int? ?? 0;
    final absent  = _stats['absent']  as int? ?? 0;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 220,
            floating: false, pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(student: _student),
            ),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Attendance'),
                Tab(text: 'Mood'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ],
        body: _loadingHistory
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _tabs,
                children: [
                  // Tab 1: Attendance + heatmap
                  SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Stats card
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                      _CircleProgress(value: pct / 100, label: '${pct.toStringAsFixed(1)}%'),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                        _StatBadge(label: 'Present', value: present, color: AppColors.present),
                        _StatBadge(label: 'Late',    value: late,    color: AppColors.late),
                        _StatBadge(label: 'Absent',  value: absent,  color: AppColors.absent),
                      ]),
                    ]))),
                    const SizedBox(height: 16),
                    // Face enrollment
                    _FaceEnrollSection(student: _student, onEnroll: _enrollFace),
                    const SizedBox(height: 16),
                    // Heatmap
                    Text('Attendance Calendar', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    HeatMap(
                      datasets: _heatmapData(),
                      colorMode: ColorMode.opacity,
                      defaultColor: AppColors.dividerLight,
                      textColor: AppColors.textSecLight,
                      showColorTip: false,
                      scrollable: true,
                      colorsets: const {1: AppColors.primary, 4: AppColors.primaryDeep},
                    ),
                  ])),

                  // Tab 2: Mood trend chart
                  _MoodChart(history: _history),

                  // Tab 3: Recent history
                  _HistoryList(records: _history),
                ],
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Student student;
  const _ProfileHeader({required this.student});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 8),
      child: Row(children: [
        CircleAvatar(
          radius: 36, backgroundColor: Colors.white24,
          child: Text(student.name[0], style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(student.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('${student.rollNo} · ${student.pnr}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Row(children: [
            _Badge(student.semester, AppColors.info),
            const SizedBox(width: 6),
            _Badge(student.batchYear, AppColors.primaryDeep),
            if (student.streak > 1) ...[
              const SizedBox(width: 6),
              _Badge('🔥${student.streak}', AppColors.streak),
            ],
          ]),
        ])),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _CircleProgress extends StatelessWidget {
  final double value; final String label;
  const _CircleProgress({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final color = value >= 0.75 ? AppColors.present : value >= 0.5 ? AppColors.warning : AppColors.error;
    return SizedBox(
      width: 90, height: 90,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: value, color: color,
          backgroundColor: color.withValues(alpha: 0.15), strokeWidth: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      ]),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label; final int value; final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecLight)),
  ]);
}

class _FaceEnrollSection extends StatelessWidget {
  final Student student;
  final VoidCallback onEnroll;
  const _FaceEnrollSection({required this.student, required this.onEnroll});
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Face Images (${student.enrolledFaces}/${AppConstants.maxFaceImages})',
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          ...List.generate(AppConstants.maxFaceImages, (i) {
            final hasImage = i < student.enrolledFaces;
            return GestureDetector(
              onTap: hasImage ? null : onEnroll,
              child: Container(
                width: 72, height: 72,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: hasImage ? AppColors.surfaceVarLight : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasImage ? AppColors.primary : AppColors.dividerLight,
                    width: hasImage ? 2 : 1,
                  ),
                ),
                child: Icon(
                  hasImage ? Icons.face : Icons.add_photo_alternate_outlined,
                  color: hasImage ? AppColors.primary : AppColors.textSecLight,
                  size: 28,
                ),
              ),
            );
          }),
        ]),
        if (student.enrolledFaces < AppConstants.maxFaceImages) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onEnroll,
            icon: const Icon(Icons.add),
            label: const Text('Add Face Photo'),
          ),
        ],
      ],
    )));
  }
}

class _MoodChart extends StatelessWidget {
  final List<AttendanceRecord> history;
  const _MoodChart({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('No mood data yet'));
    }

    final Map<String, int> moodCount = {'HAPPY': 0, 'CALM': 0, 'SAD': 0};
    for (final r in history) {
      if (r.emotion != null && moodCount.containsKey(r.emotion!.toUpperCase())) {
        moodCount[r.emotion!.toUpperCase()] = moodCount[r.emotion!.toUpperCase()]! + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mood Distribution', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                _bar(0, moodCount['HAPPY']!.toDouble(), AppColors.present),
                _bar(1, moodCount['CALM']!.toDouble(),  AppColors.calm),
                _bar(2, moodCount['SAD']!.toDouble(),   AppColors.sad),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    const labels = ['😊 Happy', '😌 Calm', '😔 Sad'];
                    return Text(labels[v.toInt()], style: const TextStyle(fontSize: 11));
                  },
                )),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            )),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
    x: x,
    barRods: [BarChartRodData(toY: y, color: color, width: 32, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
  );
}

class _HistoryList extends StatelessWidget {
  final List<AttendanceRecord> records;
  const _HistoryList({required this.records});

  String _emojiFor(String? e) {
    switch (e?.toUpperCase()) {
      case 'HAPPY': return '😊'; case 'CALM': return '😌'; case 'SAD': return '😔'; default: return '';
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'present': return AppColors.present;
      case 'late':    return AppColors.late;
      default:        return AppColors.absent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const Center(child: Text('No attendance records'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (_, i) {
        final r = records[i];
        return ListTile(
          leading: Container(
            width: 4, height: 40,
            decoration: BoxDecoration(
              color: _statusColor(r.status),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: Text('${r.sessionType} · ${r.date}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text('${r.time} · ${r.method}  ${_emojiFor(r.emotion)}', style: const TextStyle(fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(r.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(r.status,
              style: TextStyle(color: _statusColor(r.status), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}
