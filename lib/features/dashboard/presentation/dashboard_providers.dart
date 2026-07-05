import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DashboardRepository(db);
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchStats();
});
