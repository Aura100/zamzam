import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/expenses_repository.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ExpensesRepository(db);
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final repository = ref.watch(expensesRepositoryProvider);
  return repository.watchAllExpenses();
});
