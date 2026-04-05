// lib/features/dashboard/presentation/dashboard_screen.dart
// Full dashboard: greeting, animated stat cards, session grid,
// streak leaderboard, anomaly alerts, mood bar, recent scans
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/presentation/auth_provider.dart';
import 'dashboard_provider.dart';
import '../domain/dashboard_models.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: AppConstants.dashboardRefreshSec),
      (_) => _refresh(),
    );
  }

  void _refresh() {
    ref.invalidate(todayStatsProvider);
    ref.invalidate(streaksProvider);
    ref.invalidate(anomaliesProvider);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(todayStatsProvider);
    final streaksAsync = ref.watch(streaksProvider);
    final anomaliesAsync = ref.watch(anomaliesProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Greeting header ──────────────────────────
          _GreetingHeader(name: user?.name ?? 'Faculty')
            .animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          // ── Stat cards ───────────────────────────────
          statsAsync.when(
            loading: () => _ShimmerRow(),
            error: (e, _) => _ErrorCard(onRetry: _refresh),
            data: (stats) => Column(
              children: [
                _StatCardsRow(stats: stats)
                  .animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),
                _SessionGrid(sessions: stats.sessions)
                  .animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 20),
                _RecentScans(scans: stats.recentScans)
                  .animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Streak leaderboard ───────────────────────
          streaksAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (streaks) => streaks.isEmpty ? const SizedBox.shrink()
                : _StreakLeaderboard(streaks: streaks)
                    .animate().fadeIn(delay: 300.ms),
          ),

          const SizedBox(height: 20),

          // ── Anomaly alerts ───────────────────────────
          anomaliesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (anomalies) => anomalies.isEmpty ? const SizedBox.shrink()
                : _AnomalySection(anomalies: anomalies)
                    .animate().fadeIn(delay: 350.ms),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// COMPONENTS
// ════════════════════════════════════════════════════

class _GreetingHeader extends StatelessWidget {
  final String name;
  const _GreetingHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          IstUtils.getGreeting(name.split(' ').first),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          IstUtils.formatDateLong(IstUtils.now()),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _StatCardsRow extends StatelessWidget {
  final TodayStats stats;
  const _StatCardsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatCard(icon: Icons.people_outline,  label: 'Students',   value: '${stats.totalStudents}', color: AppColors.info),
          _StatCard(icon: Icons.check_circle_outline, label: 'Today %', value: '${stats.attendancePercent.toStringAsFixed(1)}%', color: AppColors.primary),
          _StatCard(icon: Icons.timer_outlined,  label: 'Session',    value: stats.activeSession ?? 'None', color: AppColors.warning, pulse: stats.activeSession != null),
          _StatCard(icon: Icons.warning_outlined, label: 'Defaulters', value: '${stats.defaulterCount}', color: stats.defaulterCount > 0 ? AppColors.error : AppColors.success),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  final bool     pulse;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            if (pulse) ...[
              const SizedBox(width: 4),
              _PulseDot(color: color),
            ],
          ]),
          Text(value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
            duration: 2.seconds, color: color.withValues(alpha: 0.3),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: 4, backgroundColor: color)
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .fadeOut(duration: 800.ms);
  }
}

class _SessionGrid extends StatelessWidget {
  final List<SessionSummary> sessions;
  const _SessionGrid({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final displayed = sessions.isEmpty
        ? ['Morning', 'Interval', 'Afternoon', 'Evening']
            .map((n) => SessionSummary(name: n, present: 0, absent: 0, late: 0, isActive: false))
            .toList()
        : sessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session Summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: displayed.map((s) => _SessionCard(session: s)).toList(),
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionSummary session;
  const _SessionCard({required this.session});

  Color _barColor(double p) {
    if (p >= 0.75) return AppColors.present;
    if (p >= 0.5)  return AppColors.warning;
    return AppColors.absent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor(session.percent);
    final isActive = session.isActive;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: isActive
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: isActive ? [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(session.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (isActive) ...[
              const SizedBox(width: 4),
              const CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
            ],
          ]),
          Text(
            '${session.present}P  ${session.late}L  ${session.absent}A',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecLight),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: session.percent,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakLeaderboard extends StatelessWidget {
  final List<StreakEntry> streaks;
  const _StreakLeaderboard({required this.streaks});

  String _medal(int rank) {
    switch (rank) { case 1: return '🥇'; case 2: return '🥈'; case 3: return '🥉'; default: return '#$rank'; }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text('Top Streaks', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 12),
        ...streaks.asMap().entries.map((e) {
          final s = e.value;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Text(_medal(s.rank), style: const TextStyle(fontSize: 22)),
            title: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.streak.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('🔥 ${s.streak} days',
                style: const TextStyle(color: AppColors.streak, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ).animate().fadeIn(delay: (e.key * 60).ms);
        }),
      ],
    );
  }
}

class _AnomalySection extends StatefulWidget {
  final List<AnomalyAlert> anomalies;
  const _AnomalySection({required this.anomalies});
  @override State<_AnomalySection> createState() => _AnomalySectionState();
}

class _AnomalySectionState extends State<_AnomalySection> {
  late List<bool> _dismissed;
  @override void initState() {
    super.initState();
    _dismissed = List.filled(widget.anomalies.length, false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.anomalies.asMap().entries.where((e) => !_dismissed[e.key]).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: 6),
          Text('Attention Needed', style: Theme.of(context).textTheme.titleLarge),
        ]),
        const SizedBox(height: 12),
        ...visible.map((entry) {
          final a = entry.value;
          final borderColor = a.severity == 'high' ? AppColors.error : AppColors.warning;
          return Dismissible(
            key: ValueKey('anomaly_${entry.key}'),
            onDismissed: (_) => setState(() => _dismissed[entry.key] = true),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: borderColor, width: 4)),
              ),
              child: Row(children: [
                Icon(Icons.person_outline, color: borderColor),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(a.pattern, style: Theme.of(context).textTheme.bodySmall),
                  ],
                )),
                Icon(a.severity == 'high' ? Icons.error_outline : Icons.info_outline,
                  color: borderColor, size: 20),
              ]),
            ).animate().fadeIn().slideX(begin: 0.1, end: 0),
          );
        }),
      ],
    );
  }
}

class _RecentScans extends StatelessWidget {
  final List<RecentScan> scans;
  const _RecentScans({required this.scans});

  String _emojiFor(String? emotion) {
    switch (emotion?.toUpperCase()) {
      case 'HAPPY':     return '😊';
      case 'CALM':      return '😌';
      case 'SAD':       return '😔';
      case 'SURPRISED': return '😮';
      default:          return '';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present': return AppColors.present;
      case 'late':    return AppColors.late;
      default:        return AppColors.absent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Scans', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ...scans.take(15).toList().asMap().entries.map((e) {
          final scan = e.value;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(scan.studentName.isNotEmpty ? scan.studentName[0] : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            title: Text('${scan.studentName} ${_emojiFor(scan.emotion)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text('${scan.session} · ${scan.time}',
              style: const TextStyle(fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(scan.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(scan.status,
                style: TextStyle(
                  color: _statusColor(scan.status),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
            ),
          ).animate().fadeIn(delay: (e.key * 40).ms);
        }),
      ],
    );
  }
}

// ── Loading / Error helpers ──────────────────────────

class _ShimmerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SizedBox(
        height: 110,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: List.generate(4, (_) => Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          )),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.wifi_off, color: AppColors.textSecLight, size: 40),
          const SizedBox(height: 8),
          const Text('Failed to load data'),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}
