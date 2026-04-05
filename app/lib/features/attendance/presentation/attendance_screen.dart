// lib/features/attendance/presentation/attendance_screen.dart
// 3-tab: Manual Mark | Records | Defaulters
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecLight,
          tabs: const [
            Tab(text: 'Mark'),
            Tab(text: 'Records'),
            Tab(text: 'Defaulters'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ManualAttendanceTab(),
          _RecordsTab(),
          _DefaultersTab(),
        ],
      ),
    );
  }
}

// ── TAB 1: Manual Attendance ─────────────────────────
class _ManualAttendanceTab extends StatefulWidget {
  const _ManualAttendanceTab();
  @override State<_ManualAttendanceTab> createState() => _ManualAttendanceTabState();
}

class _ManualAttendanceTabState extends State<_ManualAttendanceTab> {
  DateTime _date = DateTime.now();
  String   _session = AppConstants.sessionTypes.first;
  final _reasonCtrl = TextEditingController();
  final _selectedIds = <String>{};
  List<Map<String, dynamic>> _students = [];
  bool _loading = false;
  bool _submitted = false;

  @override
  void initState() { super.initState(); _loadStudents(); }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.students, params: {'status': 'active'});
      setState(() {
        _students = List<Map<String, dynamic>>.from(res['students'] as List);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one student')));
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reason is required')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post(ApiConstants.attendanceManual, data: {
        'studentIds': _selectedIds.toList(),
        'date': _date.toIso8601String().split('T').first,
        'sessionType': _session,
        'reason': _reasonCtrl.text.trim(),
        'status': 'Present',
      });
      final count = _selectedIds.length;
      setState(() { _submitted = true; _loading = false; _selectedIds.clear(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Marked $count students as present'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Step 1: Date + Session
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('${_date.day}/${_date.month}/${_date.year}'),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
          )),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(
            value: _session,
            decoration: const InputDecoration(labelText: 'Session', isDense: true),
            items: AppConstants.sessionTypes.map((s) =>
                DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _session = v!),
          )),
        ]),
      ),

      // Step 2: Student list with checkboxes
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView.builder(
                itemCount: _students.length,
                itemBuilder: (_, i) {
                  final s = _students[i];
                  final id = s['studentId'] as String;
                  return CheckboxListTile(
                    activeColor: AppColors.primary,
                    title: Text(s['name'] as String),
                    subtitle: Text(s['rollNo'] as String),
                    value: _selectedIds.contains(id),
                    onChanged: (v) => setState(() {
                      if (v == true) _selectedIds.add(id);
                      else _selectedIds.remove(id);
                    }),
                  );
                },
              ),
      ),

      // Step 3: Reason + Submit
      Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(children: [
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
              hintText: 'Medical, late arrival...',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: Text('Mark ${_selectedIds.length} Students'),
          ),
        ]),
      ),
    ]);
  }
}

// ── TAB 2: Records ───────────────────────────────────
class _RecordsTab extends StatefulWidget {
  const _RecordsTab();
  @override State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String _methodFilter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.attendanceRecords,
          params: {'limit': '50'});
      setState(() {
        _records = List<Map<String, dynamic>>.from(res['records'] as List? ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
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
    final filtered = _methodFilter == 'all'
        ? _records
        : _records.where((r) => r['method'] == _methodFilter).toList();

    return Column(children: [
      // Filter chips
      SizedBox(height: 48, child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final m in ['all', 'auto', 'mobile', 'manual'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(m[0].toUpperCase() + m.substring(1)),
                selected: _methodFilter == m,
                onSelected: (_) => setState(() => _methodFilter = m),
                selectedColor: AppColors.surfaceVarLight,
              ),
            ),
        ],
      )),

      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final r = filtered[i];
                  final status = r['status'] as String? ?? '';
                  final method = r['method'] as String? ?? 'auto';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(status).withValues(alpha: 0.15),
                      child: Text(status.isNotEmpty ? status[0] : '-',
                        style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700)),
                    ),
                    title: Text(r['studentName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('${r['sessionType']} · ${r['date']} · ${r['time']}', style: const TextStyle(fontSize: 12)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: method == 'manual' ? AppColors.info.withValues(alpha: 0.12) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(method, style: TextStyle(fontSize: 10, color: method == 'manual' ? AppColors.info : AppColors.textSecLight)),
                      ),
                    ]),
                  );
                },
              ),
            )),
    ]);
  }
}

// ── TAB 3: Defaulters ────────────────────────────────
class _DefaultersTab extends StatefulWidget {
  const _DefaultersTab();
  @override State<_DefaultersTab> createState() => _DefaultersTabState();
}

class _DefaultersTabState extends State<_DefaultersTab> {
  double _threshold = AppConstants.defaulterThreshold;
  List<Map<String, dynamic>> _defaulters = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.attendanceDefaulters,
          params: {'threshold': '$_threshold'});
      setState(() {
        _defaulters = List<Map<String, dynamic>>.from(res['defaulters'] as List? ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const Text('Threshold: ', style: TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Slider(
            value: _threshold,
            min: 50, max: 90, divisions: 8,
            activeColor: AppColors.primary,
            label: '${_threshold.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _threshold = v),
            onChangeEnd: (_) => _load(),
          )),
          SizedBox(width: 48, child: Text('${_threshold.toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ),

      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _defaulters.isEmpty
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.celebration, size: 64, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text('🎉 No defaulters at ${_threshold.toStringAsFixed(0)}%!',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                ])
              : ListView.builder(
                  itemCount: _defaulters.length,
                  itemBuilder: (_, i) {
                    final d = _defaulters[i];
                    final pct = (d['percentage'] as num?)?.toDouble() ?? 0;
                    final color = pct < 50 ? AppColors.error : AppColors.warning;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Text((d['name'] as String? ?? '?')[0],
                              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d['name'] as String? ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${d['rollNo']} · ${d['semester']}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecLight)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct / 100, color: color,
                                backgroundColor: color.withValues(alpha: 0.15),
                                minHeight: 6,
                              ),
                            ),
                          ])),
                          const SizedBox(width: 12),
                          Text('${pct.toStringAsFixed(1)}%',
                            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                        ]),
                      ),
                    );
                  },
                ),
      ),
    ]);
  }
}
