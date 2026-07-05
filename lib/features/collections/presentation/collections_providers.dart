import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/collections_repository.dart';

final collectionsRepositoryProvider = Provider<CollectionsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CollectionsRepository(db);
});

final todayInstallmentsProvider = StreamProvider<List<InstallmentWithDetails>>((ref) {
  final repository = ref.watch(collectionsRepositoryProvider);
  return repository.watchDueInstallments(DateTime.now());
});

final overdueInstallmentsProvider = StreamProvider<List<InstallmentWithDetails>>((ref) {
  final repository = ref.watch(collectionsRepositoryProvider);
  return repository.watchOverdueInstallments();
});

final collectionsGovernorateFilterProvider = StateProvider<String?>((ref) => null);
final collectionsAreaFilterProvider = StateProvider<String?>((ref) => null);
