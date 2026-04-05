// lib/features/dashboard/presentation/dashboard_provider.dart
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

final _repo = DashboardRepository();

final todayStatsProvider = FutureProvider.autoDispose<TodayStats>(
  (_) => _repo.getTodayStats(),
);

final streaksProvider = FutureProvider.autoDispose<List<StreakEntry>>(
  (_) => _repo.getStreaks(),
);

final anomaliesProvider = FutureProvider.autoDispose<List<AnomalyAlert>>(
  (_) => _repo.getAnomalies(),
);
