import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/maintenance_repository.dart';
import '../data/maintenance_schedules_repository.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MaintenanceRepository(db);
});

final maintenanceRequestsStreamProvider = StreamProvider<List<MaintenanceRequest>>((ref) {
  final repository = ref.watch(maintenanceRepositoryProvider);
  return repository.watchAllRequests();
});

final maintenancePartsProvider = FutureProvider.family<List<MaintenancePart>, int>((ref, requestId) {
  final repository = ref.watch(maintenanceRepositoryProvider);
  return repository.getPartsForRequest(requestId);
});

final maintenanceSchedulesRepositoryProvider = Provider<MaintenanceSchedulesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MaintenanceSchedulesRepository(db);
});

final maintenanceSchedulesStreamProvider = StreamProvider<List<MaintenanceSchedule>>((ref) {
  final repository = ref.watch(maintenanceSchedulesRepositoryProvider);
  return repository.watchAllSchedules();
});

final maintenanceGovernorateFilterProvider = StateProvider<String?>((ref) => null);
final maintenanceAreaFilterProvider = StateProvider<String?>((ref) => null);
