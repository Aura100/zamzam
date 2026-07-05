import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ProductsRepository {
  final AppDatabase _db;

  ProductsRepository(this._db);

  Stream<List<Product>> watchAllProducts() {
    return (_db.select(_db.products)..where((t) => t.isDeleted.equals(false))).watch();
  }

  Stream<List<Product>> watchProductsByType(int type) {
    return (_db.select(_db.products)..where((t) => t.isDeleted.equals(false) & t.productType.equals(type))).watch();
  }

  Future<int> addProduct(ProductsCompanion product) {
    return _db.into(_db.products).insert(product);
  }

  Future<bool> updateProduct(Product product) {
    return _db.update(_db.products).replace(product);
  }

  Future<int> deleteProduct(int id) {
    return (_db.update(_db.products)..where((t) => t.id.equals(id)))
        .write(const ProductsCompanion(isDeleted: Value(true)));
  }
}
