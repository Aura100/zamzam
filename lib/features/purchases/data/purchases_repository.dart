import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class SuppliersRepository {
  final AppDatabase _db;
  SuppliersRepository(this._db);

  Stream<List<Supplier>> watchAllSuppliers() =>
      (_db.select(_db.suppliers)..where((t) => t.isDeleted.equals(false))).watch();

  Future<void> addSupplier(SuppliersCompanion supplier) async {
    await _db.into(_db.suppliers).insert(supplier);
  }

  Future<void> updateSupplier(SuppliersCompanion supplier) async {
    await _db.update(_db.suppliers).replace(supplier);
  }

  Future<void> deleteSupplier(int id) async {
    await (_db.update(_db.suppliers)..where((t) => t.id.equals(id)))
        .write(const SuppliersCompanion(isDeleted: Value(true)));
  }

  /// Returns a map of supplierId -> {totalAmount, paidAmount, remaining}
  Future<Map<int, Map<String, double>>> getSupplierLedger() async {
    final purchases = await _db.select(_db.purchaseInvoices).get();
    final Map<int, Map<String, double>> ledger = {};
    for (final p in purchases) {
      if (p.supplierId == null) continue;
      final sid = p.supplierId!;
      ledger.putIfAbsent(sid, () => {'totalAmount': 0.0, 'paidAmount': 0.0, 'remaining': 0.0});
      ledger[sid]!['totalAmount'] = ledger[sid]!['totalAmount']! + p.totalAmount;
      ledger[sid]!['paidAmount'] = ledger[sid]!['paidAmount']! + p.paidAmount;
      ledger[sid]!['remaining'] = ledger[sid]!['totalAmount']! - ledger[sid]!['paidAmount']!;
    }
    return ledger;
  }
}

class PurchasesRepository {
  final AppDatabase _db;
  PurchasesRepository(this._db);

  Stream<List<PurchaseInvoice>> watchAllPurchases() =>
      (_db.select(_db.purchaseInvoices)
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .watch();

  Future<void> createPurchase({
    required PurchaseInvoicesCompanion invoice,
    required List<PurchaseItemsCompanion> items,
  }) async {
    await _db.transaction(() async {
      final invoiceId = await _db.into(_db.purchaseInvoices).insert(invoice);

      for (final item in items) {
        final itemWithInvoice = item.copyWith(purchaseInvoiceId: Value(invoiceId));
        await _db.into(_db.purchaseItems).insert(itemWithInvoice);

        // Increase product stock
        final productId = item.productId.value;
        final product = await (_db.select(_db.products)
              ..where((t) => t.id.equals(productId)))
            .getSingle();
        final newStock = product.currentStock + item.quantity.value;
        await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
            .write(ProductsCompanion(currentStock: Value(newStock)));

        // Log inventory movement
        await _db.into(_db.inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(productId),
            type: const Value('IN'),
            quantity: item.quantity,
            referenceId: Value('PO-$invoiceId'),
            notes: const Value('مشتريات من المورد'),
          ),
        );
      }
    });
  }

  /// Record a payment towards a purchase invoice (supplier debt reduction)
  Future<void> recordPayment(int invoiceId, double amount) async {
    final invoice = await (_db.select(_db.purchaseInvoices)
          ..where((t) => t.id.equals(invoiceId)))
        .getSingle();
    final newPaid = invoice.paidAmount + amount;
    await (_db.update(_db.purchaseInvoices)
          ..where((t) => t.id.equals(invoiceId)))
        .write(PurchaseInvoicesCompanion(paidAmount: Value(newPaid)));
  }
}
