import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class CustomersRepository {
  final AppDatabase _db;

  CustomersRepository(this._db);

  Stream<List<Customer>> watchAllCustomers() {
    return (_db.select(_db.customers)..where((t) => t.isDeleted.equals(false))).watch();
  }

  Future<int> addCustomer(CustomersCompanion customer) {
    return _db.into(_db.customers).insert(customer);
  }

  Future<bool> updateCustomer(Customer customer) {
    return _db.update(_db.customers).replace(customer);
  }

  Future<int> deleteCustomer(int id) {
    return (_db.update(_db.customers)..where((t) => t.id.equals(id)))
        .write(const CustomersCompanion(isDeleted: Value(true)));
  }

  Future<Customer?> getCustomerById(int id) {
    return (_db.select(_db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> addLegacyCustomer({
    required CustomersCompanion customer,
    required int productId,
    required DateTime purchaseDate,
    required DateTime lastMaintenanceDate,
    required int cycleMonths,
    required double remainingDebt,
  }) async {
    await _db.transaction(() async {
      // 1. Add Customer
      final customerId = await _db.into(_db.customers).insert(customer);

      // 2. Add Invoice
      final invoiceId = await _db.into(_db.salesInvoices).insert(
        SalesInvoicesCompanion.insert(
          invoiceNumber: 'LEGACY-${DateTime.now().millisecondsSinceEpoch}-$customerId',
          customerId: customerId,
          paymentType: remainingDebt > 0 ? 'INSTALLMENT' : 'CASH',
          totalAmount: remainingDebt > 0 ? remainingDebt : 0.0,
          date: Value(purchaseDate),
        ),
      );

      // 3. Add Invoice Item
      await _db.into(_db.invoiceItems).insert(
        InvoiceItemsCompanion.insert(
          invoiceId: invoiceId,
          productId: productId,
          quantity: 1,
          unitPrice: remainingDebt > 0 ? remainingDebt : 0.0,
        ),
      );

      // 4. Add Maintenance Schedule
      await _db.into(_db.maintenanceSchedules).insert(
        MaintenanceSchedulesCompanion.insert(
          customerId: customerId,
          productId: Value(productId),
          cycleMonths: cycleMonths,
          lastMaintenanceDate: lastMaintenanceDate,
          nextMaintenanceDate: lastMaintenanceDate.add(Duration(days: cycleMonths * 30)),
        ),
      );

      // 5. Add Debt (if any)
      if (remainingDebt > 0) {
        final contractId = await _db.into(_db.installmentContracts).insert(
          InstallmentContractsCompanion.insert(
            contractNumber: 'LEG-${DateTime.now().millisecondsSinceEpoch}-$customerId',
            invoiceId: invoiceId,
            customerId: customerId,
            downPayment: 0.0,
            remainingBalance: remainingDebt,
            months: 1,
            monthlyAmount: remainingDebt,
            startDate: purchaseDate,
            nextDueDate: Value(DateTime.now()),
          ),
        );

        await _db.into(_db.installments).insert(
          InstallmentsCompanion.insert(
            contractId: contractId,
            dueDate: DateTime.now(),
            amount: remainingDebt,
          ),
        );
      }
    });
  }
}
