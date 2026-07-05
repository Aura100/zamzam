import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/customers_repository.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CustomersRepository(db);
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final repository = ref.watch(customersRepositoryProvider);
  return repository.watchAllCustomers();
});
