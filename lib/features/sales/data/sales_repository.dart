import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class SalesRepository {
  final AppDatabase _db;

  SalesRepository(this._db);

  Stream<List<SalesInvoice>> watchAllInvoices() {
    return _db.select(_db.salesInvoices).watch();
  }

  Future<void> createCashSale({
    required SalesInvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
  }) async {
    await _db.transaction(() async {
      // 1. Insert Invoice
      final invoiceId = await _db.into(_db.salesInvoices).insert(invoice);

      // 2. Insert Items and Update Stock
      for (var item in items) {
        final itemWithInvoice = item.copyWith(invoiceId: Value(invoiceId));
        await _db.into(_db.invoiceItems).insert(itemWithInvoice);

        // Update Stock
        final productId = item.productId.value;
        final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
        final newStock = product.currentStock - item.quantity.value;
        
        await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
            .write(ProductsCompanion(currentStock: Value(newStock)));

        // Insert Inventory Movement
        await _db.into(_db.inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(productId),
            type: const Value('OUT'),
            quantity: item.quantity,
            referenceId: Value('INV-$invoiceId'),
            notes: const Value('Cash Sale'),
          ),
        );
      }
    });
  }

  Future<void> createInstallmentSale({
    required SalesInvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
    required InstallmentContractsCompanion contract,
    required List<InstallmentsCompanion> installments,
  }) async {
    await _db.transaction(() async {
      // 1. Insert Invoice
      final invoiceId = await _db.into(_db.salesInvoices).insert(invoice);

      // 2. Insert Items and Update Stock
      for (var item in items) {
        final itemWithInvoice = item.copyWith(invoiceId: Value(invoiceId));
        await _db.into(_db.invoiceItems).insert(itemWithInvoice);

        // Update Stock
        final productId = item.productId.value;
        final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
        final newStock = product.currentStock - item.quantity.value;
        
        await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
            .write(ProductsCompanion(currentStock: Value(newStock)));

        // Insert Inventory Movement
        await _db.into(_db.inventoryMovements).insert(
          InventoryMovementsCompanion(
            productId: Value(productId),
            type: const Value('OUT'),
            quantity: item.quantity,
            referenceId: Value('INV-$invoiceId'),
            notes: const Value('Installment Sale'),
          ),
        );
      }

      // 3. Insert Contract
      final contractWithInvoice = contract.copyWith(invoiceId: Value(invoiceId));
      final contractId = await _db.into(_db.installmentContracts).insert(contractWithInvoice);

      // 4. Insert Installments Schedule
      for (var inst in installments) {
        final instWithContract = inst.copyWith(contractId: Value(contractId));
        await _db.into(_db.installments).insert(instWithContract);
      }
    });
  }
}
