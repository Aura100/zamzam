import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Customers,
    Products,
    InventoryMovements,
    SalesInvoices,
    InvoiceItems,
    InstallmentContracts,
    Installments,
    MaintenanceRequests,
    Expenses,
    Suppliers,
    PurchaseInvoices,
    PurchaseItems,
    MaintenanceParts,
    MaintenanceSchedules,
    InventoryAudits,
    SalesReturns,
    SalesReturnItems,
    EmployeeProfiles,
    PayrollTransactions,
    MonthlyPayrolls,
    TechnicianCustody,
    CashDrawerSessions,
    CompanySettings,
    TechnicianCommissionRates,
    MaintenancePayments,
    Offers,
    OfferItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.open(String path) : super(NativeDatabase(File(path)));

  AppDatabase.withExecutor(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Insert a default admin user
        await into(users).insert(
          UsersCompanion.insert(
            name: 'مدير النظام',
            role: 'Administrator',
            pinCode: '0000',
            permissions: const Value('ALL'),
          ),
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add new tables
          await m.createTable(suppliers);
          await m.createTable(purchaseInvoices);
          await m.createTable(purchaseItems);
        }
        if (from < 3) {
          await m.createTable(maintenanceParts);
        }
        if (from < 4) {
          await m.createTable(maintenanceSchedules);
          await m.addColumn(
            maintenanceRequests,
            maintenanceRequests.isInternal,
          );
          await m.addColumn(
            maintenanceRequests,
            maintenanceRequests.scheduledTime,
          );
        }
        if (from < 5) {
          await m.addColumn(products, products.productType);
          await m.createTable(inventoryAudits);
        }
        if (from < 6) {
          await m.createTable(salesReturns);
          await m.createTable(salesReturnItems);
        }
        if (from < 7) {
          await m.createTable(employeeProfiles);
          await m.createTable(payrollTransactions);
          await m.createTable(monthlyPayrolls);
          await m.createTable(technicianCustody);
        }
        if (from < 8) {
          // Serial/warranty tracking for sold items
          await m.addColumn(invoiceItems, invoiceItems.serialNumber);
          // Supplier debt tracking
          await m.addColumn(purchaseInvoices, purchaseInvoices.paidAmount);
        }
        if (from < 9) {
          await m.createTable(cashDrawerSessions);
        }
        if (from < 10) {
          await m.createTable(companySettings);

          // Insert default settings
          await into(companySettings).insert(
            const CompanySettingsCompanion(
              key: Value('company_name'),
              value: Value('شركة زمزم للفلاتر'),
            ),
          );
          await into(companySettings).insert(
            const CompanySettingsCompanion(
              key: Value('company_phone'),
              value: Value('01000000000'),
            ),
          );
          await into(companySettings).insert(
            const CompanySettingsCompanion(
              key: Value('company_address'),
              value: Value('القاهرة، مصر'),
            ),
          );
        }
        if (from < 11) {
          await m.createTable(technicianCommissionRates);
        }
        if (from < 12) {
          await m.createTable(maintenancePayments);
        }
        if (from < 13) {
          await m.createTable(offers);
          await m.createTable(offerItems);
        }
        if (from < 14) {
          await m.addColumn(offers, offers.isBundle);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'zamzam_erp', 'zamzam_erp.sqlite'));

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    return NativeDatabase.createInBackground(file);
  });
}
