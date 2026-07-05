import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Data class for joined installment data (installment + contract + customer)
class InstallmentWithDetails {
  final Installment installment;
  final InstallmentContract contract;
  final Customer customer;

  InstallmentWithDetails({
    required this.installment,
    required this.contract,
    required this.customer,
  });
}

class CollectionsRepository {
  final AppDatabase _db;

  CollectionsRepository(this._db);

  Stream<List<InstallmentWithDetails>> watchDueInstallments(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return (_db.select(_db.installments)
          ..where((t) => t.dueDate.isBetweenValues(startOfDay, endOfDay) & t.status.equals('Pending')))
        .watch()
        .asyncMap((installments) => _joinDetails(installments));
  }

  Stream<List<InstallmentWithDetails>> watchOverdueInstallments() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return (_db.select(_db.installments)
          ..where((t) => t.dueDate.isSmallerThanValue(startOfDay) & (t.status.equals('Pending') | t.status.equals('Late'))))
        .watch()
        .asyncMap((installments) => _joinDetails(installments));
  }

  Future<List<InstallmentWithDetails>> _joinDetails(List<Installment> installments) async {
    final List<InstallmentWithDetails> result = [];
    for (final inst in installments) {
      final contract = await (_db.select(_db.installmentContracts)
            ..where((t) => t.id.equals(inst.contractId)))
          .getSingleOrNull();
      if (contract == null) continue;

      final customer = await (_db.select(_db.customers)
            ..where((t) => t.id.equals(contract.customerId)))
          .getSingleOrNull();
      if (customer == null) continue;

      result.add(InstallmentWithDetails(
        installment: inst,
        contract: contract,
        customer: customer,
      ));
    }
    return result;
  }

  /// Fetch ALL installments joined with contract and customer data
  Future<List<InstallmentWithDetails>> getAllInstallmentsWithDetails() async {
    final installments = await _db.select(_db.installments).get();
    final List<InstallmentWithDetails> result = [];

    for (final inst in installments) {
      final contract = await (_db.select(_db.installmentContracts)
            ..where((t) => t.id.equals(inst.contractId)))
          .getSingleOrNull();
      if (contract == null) continue;

      final customer = await (_db.select(_db.customers)
            ..where((t) => t.id.equals(contract.customerId)))
          .getSingleOrNull();
      if (customer == null) continue;

      result.add(InstallmentWithDetails(
        installment: inst,
        contract: contract,
        customer: customer,
      ));
    }

    // Sort by due date ascending (closest first)
    result.sort((a, b) => a.installment.dueDate.compareTo(b.installment.dueDate));
    return result;
  }

  Future<void> collectPayment({
    required int installmentId,
    required double amountPaid,
    required String receiptNumber,
    required int collectorId,
  }) async {
    final installment = await (_db.select(_db.installments)..where((t) => t.id.equals(installmentId))).getSingle();
    
    // Check if fully paid (adding small epsilon for float precision)
    final isFullyPaid = (installment.partialPaidAmount + amountPaid) >= (installment.amount - 0.01);

    await (_db.update(_db.installments)..where((t) => t.id.equals(installmentId))).write(
      InstallmentsCompanion(
        status: Value(isFullyPaid ? 'Paid' : 'Pending'),
        paidDate: Value(DateTime.now()),
        receiptNumber: Value(receiptNumber),
        collectorId: Value(collectorId),
        partialPaidAmount: Value(installment.partialPaidAmount + amountPaid),
      ),
    );
    
    // Also update Contract Remaining Balance
    final contract = await (_db.select(_db.installmentContracts)..where((t) => t.id.equals(installment.contractId))).getSingle();
    await (_db.update(_db.installmentContracts)..where((t) => t.id.equals(contract.id))).write(
      InstallmentContractsCompanion(
        remainingBalance: Value(contract.remainingBalance - amountPaid),
      ),
    );
  }
}
