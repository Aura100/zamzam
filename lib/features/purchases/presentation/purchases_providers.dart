import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/purchases_repository.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository(ref.watch(databaseProvider));
});

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(databaseProvider));
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(suppliersRepositoryProvider).watchAllSuppliers();
});

final purchasesStreamProvider = StreamProvider<List<PurchaseInvoice>>((ref) {
  return ref.watch(purchasesRepositoryProvider).watchAllPurchases();
});
