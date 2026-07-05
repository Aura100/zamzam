import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zamzam/core/database/app_database.dart';
import 'package:zamzam/core/services/archive_analysis_service.dart';

void main() {
  test(
    'archive analysis includes maintenance and commission metrics',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'archive_analysis_test',
      );
      final dbPath = p.join(tempDir.path, 'archive.sqlite');
      final db = AppDatabase.open(dbPath);

      try {
        final userId = await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                name: 'فني',
                role: 'Technician',
                pinCode: '1234',
                phone: const drift.Value('01000000000'),
              ),
            );

        final customerId = await db
            .into(db.customers)
            .insert(
              CustomersCompanion.insert(name: 'عميل', phone1: '01000000001'),
            );

        final productId = await db
            .into(db.products)
            .insert(ProductsCompanion.insert(name: 'منتج', category: 'معدات'));

        final employeeId = await db
            .into(db.employeeProfiles)
            .insert(
              EmployeeProfilesCompanion.insert(
                userId: userId,
                baseSalary: const drift.Value(5000.0),
              ),
            );

        final invoiceId = await db
            .into(db.salesInvoices)
            .insert(
              SalesInvoicesCompanion.insert(
                invoiceNumber: 'INV-001',
                customerId: customerId,
                paymentType: 'CASH',
                totalAmount: 2500,
                discount: const drift.Value(100.0),
                tax: const drift.Value(0.0),
                deliveryFees: const drift.Value(0.0),
                installationFees: const drift.Value(0.0),
              ),
            );

        await db
            .into(db.invoiceItems)
            .insert(
              InvoiceItemsCompanion.insert(
                invoiceId: invoiceId,
                productId: productId,
                quantity: 2,
                unitPrice: 1000,
              ),
            );

        final maintenanceId = await db
            .into(db.maintenanceRequests)
            .insert(
              MaintenanceRequestsCompanion.insert(
                customerId: customerId,
                issueDescription: 'تلف',
                scheduledDate: DateTime(2024, 1, 10),
                isInternal: const drift.Value(false),
                technicianId: drift.Value(userId),
                cost: const drift.Value(300.0),
              ),
            );

        await db
            .into(db.maintenancePayments)
            .insert(
              MaintenancePaymentsCompanion.insert(
                requestId: maintenanceId,
                technicianId: userId,
                totalCollected: 400,
                commissionPercent: const drift.Value(10.0),
                commissionAmount: 40,
                amountHandedOver: 360,
              ),
            );

        await db
            .into(db.payrollTransactions)
            .insert(
              PayrollTransactionsCompanion.insert(
                employeeId: employeeId,
                type: 'BONUS',
                amount: 300,
                description: const drift.Value('مكافأة'),
              ),
            );

        final result = await ArchiveAnalysisService.analyzeArchive(dbPath);

        expect(result.totalInvoices, 1);
        expect(result.totalSales, 2500);
        expect(result.totalMaintenanceRequests, 1);
        expect(result.totalInternalMaintenance, 0);
        expect(result.totalExternalMaintenance, 1);
        expect(result.totalMaintenanceCommissionAmount, 40);
        expect(result.totalPayrollTransactions, 1);
        expect(result.totalPayrollAmount, 300);
      } finally {
        await db.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );
}
