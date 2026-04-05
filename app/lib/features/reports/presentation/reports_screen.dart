// lib/features/reports/presentation/reports_screen.dart
// Reports: Generate (Excel/PDF), Analytics (charts), Digest
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/date_utils.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecLight,
          tabs: const [Tab(text: 'Generate'), Tab(text: 'Analytics'), Tab(text: 'Digest')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_GenerateTab(), _AnalyticsTab(), _DigestTab()],
      ),
    );
  }
}

// ── TAB 1: Generate ──────────────────────────────────
class _GenerateTab extends StatefulWidget {
  const _GenerateTab();
  @override State<_GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends State<_GenerateTab> {
  String   _type      = 'excel';
  DateTime _from      = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to        = DateTime.now();
  String?  _batch;
  String?  _semester;
  bool     _loading   = false;
  List<Map<String, dynamic>> _recentReports = [];
  String?  _shareLink;
  bool     _sharing   = false;

  @override
  void initState() { super.initState(); _loadRecent(); }

  Future<void> _loadRecent() async {
    try {
      final res = await ApiClient.instance.get(ApiConstants.reportsGenerate);
      setState(() => _recentReports = List<Map<String, dynamic>>.from(res['reports'] as List? ?? []));
    } catch (_) {}
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.post(ApiConstants.reportsGenerate, data: {
        'type': _type,
        'fromDate': _from.toIso8601String().split('T').first,
        'toDate':   _to.toIso8601String().split('T').first,
        if (_batch    != null) 'batchYear': _batch,
        if (_semester != null) 'semester':  _semester,
      });
      final url = res['downloadUrl'] as String?;
      if (url != null) await launchUrl(Uri.parse(url));
      setState(() => _loading = false);
      _loadRecent();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _shareReport(String reportId) async {
    setState(() => _sharing = true);
    try {
      final res = await ApiClient.instance.post(
        '${ApiConstants.reportsShare}/$reportId', data: {});
      final link = res['shareUrl'] as String? ?? '';
      setState(() { _shareLink = link; _sharing = false; });

      await showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Share Report'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Link valid for 48 hours', style: TextStyle(color: AppColors.textSecLight, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(child: Text(link, style: const TextStyle(fontSize: 12))),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied!')));
                },
              ),
            ]),
          ),
        ]),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () => Share.share(link),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ));
    } catch (e) {
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Generate Report', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // Type toggle
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() => _type = 'excel'),
              style: OutlinedButton.styleFrom(
                backgroundColor: _type == 'excel' ? AppColors.primary : null,
                foregroundColor: _type == 'excel' ? Colors.white : null,
              ),
              icon: const Icon(Icons.table_chart, size: 16),
              label: const Text('Excel'),
            )),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() => _type = 'pdf'),
              style: OutlinedButton.styleFrom(
                backgroundColor: _type == 'pdf' ? AppColors.primary : null,
                foregroundColor: _type == 'pdf' ? Colors.white : null,
              ),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('PDF'),
            )),
          ]),
          const SizedBox(height: 16),

          // Date range
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text('From: ${_from.day}/${_from.month}/${_from.year}', style: const TextStyle(fontSize: 12)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _from,
                  firstDate: DateTime(2024), lastDate: _to);
                if (d != null) setState(() => _from = d);
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text('To: ${_to.day}/${_to.month}/${_to.year}', style: const TextStyle(fontSize: 12)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _to,
                  firstDate: _from, lastDate: DateTime.now());
                if (d != null) setState(() => _to = d);
              },
            )),
          ]),
          const SizedBox(height: 12),

          // Optional batch / semester
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _batch,
              decoration: const InputDecoration(labelText: 'Batch (opt)', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...AppConstants.batchYears.map((b) => DropdownMenuItem(value: b, child: Text(b))),
              ],
              onChanged: (v) => setState(() => _batch = v),
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<String>(
              value: _semester,
              decoration: const InputDecoration(labelText: 'Semester (opt)', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...AppConstants.semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _semester = v),
            )),
          ]),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download),
            label: Text(_loading ? 'Generating...' : 'Generate & Download'),
          ),
        ],
      ))),

      if (_recentReports.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('📥 Recent Reports', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ..._recentReports.take(10).map((r) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(r['type'] == 'excel' ? Icons.table_chart : Icons.picture_as_pdf,
              color: r['type'] == 'excel' ? AppColors.present : AppColors.error),
            title: Text('${r['type']?.toString().toUpperCase()} · ${r['fromDate']} → ${r['toDate']}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(IstUtils.formatDateTime(IstUtils.parse(r['createdAt'] as String? ?? '')),
              style: const TextStyle(fontSize: 11)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.download, size: 20), onPressed: () async {
                final url = r['downloadUrl'] as String?;
                if (url != null) await launchUrl(Uri.parse(url));
              }),
              IconButton(icon: _sharing ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.share, size: 20),
                onPressed: () => _shareReport(r['reportId'] as String)),
            ]),
          ),
        )),
      ],
    ]);
  }
}

// ── TAB 2: Analytics ─────────────────────────────────
class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();
  @override State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  String _period = '7';
  List<FlSpot>  _trendSpots = [];
  List<double?> _sessionAvgs  = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final to   = DateTime.now();
      final from = to.subtract(Duration(days: int.parse(_period)));
      final res  = await ApiClient.instance.get(ApiConstants.attendanceRecords, params: {
        'fromDate': from.toIso8601String().split('T').first,
        'toDate':   to.toIso8601String().split('T').first,
        'groupBy':  'day',
      });
      final trend = (res['trend'] as List? ?? []).asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), ((e.value as Map)['percentage'] as num?)?.toDouble() ?? 0)).toList();
      setState(() { _trendSpots = trend; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Period selector
      Row(children: [
        const Text('Period: ', style: TextStyle(fontWeight: FontWeight.w600)),
        ...['7', '30'].map((p) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ChoiceChip(
            label: Text(p == '7' ? '7 days' : '30 days'),
            selected: _period == p,
            selectedColor: AppColors.surfaceVarLight,
            onSelected: (_) { setState(() => _period = p); _load(); },
          ),
        )),
      ]),
      const SizedBox(height: 20),

      // Trend chart
      Text('Attendance Trend', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(
        height: 200,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _trendSpots.isEmpty
                ? const Center(child: Text('No data'))
                : LineChart(LineChartData(
                    lineBarsData: [LineChartBarData(
                      spots: _trendSpots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(show: true,
                        color: AppColors.primary.withValues(alpha: 0.15)),
                      dotData: const FlDotData(show: false),
                    )],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 40,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
                      )),
                    ),
                    gridData: FlGridData(
                      drawHorizontalLine: true,
                      getDrawingHorizontalLine: (_) => FlLine(color: AppColors.dividerLight, strokeWidth: 1),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0, maxY: 100,
                  )),
      ))),

      const SizedBox(height: 20),
      Text('Session Comparison', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(
        height: 180,
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: AppConstants.sessionTypes.asMap().entries.map((e) =>
              BarChartGroupData(x: e.key, barRods: [BarChartRodData(
                toY: 70 + (e.key * 5).toDouble(), // Placeholder until API returns this
                color: AppColors.primary.withValues(alpha: 0.6 + e.key * 0.1),
                width: 28,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )])).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(AppConstants.sessionTypes[v.toInt()].substring(0, 3),
                style: const TextStyle(fontSize: 11)),
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 36,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        )),
      ))),
    ]);
  }
}

// ── TAB 3: Digest ────────────────────────────────────
class _DigestTab extends StatefulWidget {
  const _DigestTab();
  @override State<_DigestTab> createState() => _DigestTabState();
}

class _DigestTabState extends State<_DigestTab> {
  Map<String, dynamic>? _digest;
  bool _loading = true;
  int  _weekOffset = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(ApiConstants.attendanceDigest,
          params: {'weekOffset': '$_weekOffset'});
      setState(() { _digest = Map<String, dynamic>.from(res as Map); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Week navigator
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left),
          onPressed: () { setState(() => _weekOffset--); _load(); }),
        Text(_weekOffset == 0 ? 'This Week' : '$_weekOffset week(s) ago',
          style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(icon: const Icon(Icons.chevron_right),
          onPressed: _weekOffset < 0 ? () { setState(() => _weekOffset++); _load(); } : null),
      ]),

      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _digest == null
              ? const Center(child: Text('No digest available'))
              : _DigestView(digest: _digest!)),
    ]);
  }
}

class _DigestView extends StatelessWidget {
  final Map<String, dynamic> digest;
  const _DigestView({required this.digest});

  @override
  Widget build(BuildContext context) {
    final totalScans   = digest['totalScans']   as int? ?? 0;
    final avgPct       = (digest['avgAttendance'] as num?)?.toDouble() ?? 0;
    final anomalies    = digest['anomalyCount'] as int? ?? 0;
    final streaks      = (digest['topStreaks']  as List? ?? []).cast<Map<String, dynamic>>();
    final moodHappy    = (digest['moodHappy']   as num?)?.toDouble() ?? 0;
    final moodCalm     = (digest['moodCalm']    as num?)?.toDouble() ?? 0;
    final moodSad      = (digest['moodSad']     as num?)?.toDouble() ?? 0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Summary row
      Row(children: [
        _DigestStat('📊', 'Total Scans',   '$totalScans'),
        _DigestStat('✅', 'Avg Attendance', '${avgPct.toStringAsFixed(1)}%'),
        _DigestStat('⚠️', 'Anomalies',     '$anomalies'),
      ]),
      const SizedBox(height: 20),

      // Mood bar
      Text('This Week\'s Vibe', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      _MoodBar(happy: moodHappy, calm: moodCalm, sad: moodSad),
      const SizedBox(height: 20),

      // Streaks
      if (streaks.isNotEmpty) ...[
        Text('🔥 Top Streaks', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...streaks.asMap().entries.map((e) {
          const medals = ['🥇', '🥈', '🥉'];
          final s = e.value;
          return ListTile(
            leading: Text(e.key < 3 ? medals[e.key] : '#${e.key + 1}',
              style: const TextStyle(fontSize: 20)),
            title: Text(s['studentName'] as String? ?? ''),
            trailing: Text('🔥${s['streak']}',
              style: const TextStyle(color: AppColors.streak, fontWeight: FontWeight.w700)),
          );
        }),
      ],
    ]);
  }
}

class _DigestStat extends StatelessWidget {
  final String emoji, label, value;
  const _DigestStat(this.emoji, this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(child: Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecLight), textAlign: TextAlign.center),
    ]),
  )));
}

class _MoodBar extends StatelessWidget {
  final double happy, calm, sad;
  const _MoodBar({required this.happy, required this.calm, required this.sad});
  @override
  Widget build(BuildContext context) {
    final total = happy + calm + sad;
    if (total == 0) return const Text('No mood data');
    return Column(children: [
      Row(children: [
        _MoodSegment('😊 ${(happy / total * 100).toStringAsFixed(0)}%', happy / total, AppColors.present),
        _MoodSegment('😌 ${(calm / total * 100).toStringAsFixed(0)}%', calm / total, AppColors.calm),
        _MoodSegment('😔 ${(sad / total * 100).toStringAsFixed(0)}%', sad / total, AppColors.sad),
      ]),
    ]);
  }
}

class _MoodSegment extends StatelessWidget {
  final String label; final double flex; final Color color;
  const _MoodSegment(this.label, this.flex, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    flex: (flex * 100).toInt().clamp(1, 100),
    child: Container(
      height: 36,
      decoration: BoxDecoration(color: color),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}
