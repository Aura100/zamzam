import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductsRepository(db);
});

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(productsRepositoryProvider);
  return repository.watchAllProducts();
});

final newProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(productsRepositoryProvider);
  return repository.watchProductsByType(0);
});

final usedProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(productsRepositoryProvider);
  return repository.watchProductsByType(1);
});
