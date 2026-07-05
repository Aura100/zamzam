import 'package:drift/drift.dart';

@DataClassName('User')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get role =>
      text()(); // Admin, Manager, Sales, Collector, Warehouse
  TextColumn get pinCode => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get permissions =>
      text().nullable()(); // JSON string of permissions
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('Customer')
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get nationalId => text().nullable()();
  TextColumn get phone1 => text()();
  TextColumn get phone2 => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get governorate => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get area => text().nullable()();
  TextColumn get landmark => text().nullable()();
  TextColumn get gpsLocation => text().nullable()();
  TextColumn get occupation => text().nullable()();
  TextColumn get workAddress => text().nullable()();
  TextColumn get guarantorName => text().nullable()();
  TextColumn get guarantorPhone => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get profilePhoto => text().nullable()();
  TextColumn get nationalIdPhotos => text().nullable()(); // JSON list
  TextColumn get contractFiles => text().nullable()(); // JSON list
  TextColumn get status => text().withDefault(const Constant('Active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('Product')
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get arabicName => text().nullable()();
  TextColumn get category => text()(); // Filters, Candles, Pumps, etc.
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get cashPrice => real().withDefault(const Constant(0.0))();
  RealColumn get installmentPrice => real().withDefault(const Constant(0.0))();
  RealColumn get wholesalePrice => real().withDefault(const Constant(0.0))();
  TextColumn get barcode => text().nullable()();
  TextColumn get sku => text().nullable()();
  TextColumn get image => text().nullable()();
  IntColumn get warrantyMonths => integer().withDefault(const Constant(0))();
  TextColumn get description => text().nullable()();
  IntColumn get minStock => integer().withDefault(const Constant(5))();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  IntColumn get supplierId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('Active'))();
  IntColumn get productType =>
      integer().withDefault(const Constant(0))(); // 0 = جديد, 1 = مستعمل
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('InventoryMovement')
class InventoryMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get type => text()(); // IN, OUT, ADJUST
  IntColumn get quantity => integer()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get referenceId => text().nullable()(); // Invoice ID, PO ID, etc.
  TextColumn get notes => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id).nullable()();
}

@DataClassName('SalesInvoice')
class SalesInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get salesmanId => integer().references(Users, #id).nullable()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get tax => real().withDefault(const Constant(0.0))();
  RealColumn get deliveryFees => real().withDefault(const Constant(0.0))();
  RealColumn get installationFees => real().withDefault(const Constant(0.0))();
  TextColumn get paymentType => text()(); // CASH, INSTALLMENT
  RealColumn get totalAmount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('InvoiceItem')
class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(SalesInvoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  TextColumn get serialNumber => text().nullable()();
}

@DataClassName('InstallmentContract')
class InstallmentContracts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get contractNumber => text().unique()();
  IntColumn get invoiceId => integer().references(SalesInvoices, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  RealColumn get downPayment => real()();
  RealColumn get remainingBalance => real()();
  RealColumn get profitMargin => real().withDefault(const Constant(0.0))();
  IntColumn get months => integer()();
  RealColumn get monthlyAmount => real()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(
    const Constant('Active'),
  )(); // Active, Completed, Cancelled
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Installment')
class Installments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contractId => integer().references(InstallmentContracts, #id)();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get amount => real()();
  TextColumn get status =>
      text().withDefault(const Constant('Pending'))(); // Pending, Paid, Late
  DateTimeColumn get paidDate => dateTime().nullable()();
  TextColumn get receiptNumber => text().nullable()();
  IntColumn get collectorId => integer().references(Users, #id).nullable()();
  RealColumn get penaltyAmount => real().withDefault(const Constant(0.0))();
  RealColumn get partialPaidAmount => real().withDefault(const Constant(0.0))();
}

@DataClassName('MaintenanceRequest')
class MaintenanceRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get productId => integer().references(Products, #id).nullable()();
  TextColumn get issueDescription => text()();
  DateTimeColumn get scheduledDate => dateTime()();
  TextColumn get scheduledTime => text().nullable()();
  BoolColumn get isInternal => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(
    const Constant('Pending'),
  )(); // Pending, InProgress, Completed
  IntColumn get technicianId => integer().references(Users, #id).nullable()();
  RealColumn get cost => real().withDefault(const Constant(0.0))();
  TextColumn get partsUsed =>
      text().nullable()(); // JSON list of product IDs/names
  DateTimeColumn get completionDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('MaintenancePart')
class MaintenanceParts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get requestId => integer().references(MaintenanceRequests, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantityOut => integer().withDefault(
    const Constant(0),
  )(); // Quantity taken by technician
  IntColumn get quantityUsed =>
      integer().withDefault(const Constant(0))(); // Quantity actually consumed
  RealColumn get unitPrice => real().withDefault(
    const Constant(0.0),
  )(); // Price charged to customer for this part
}

@DataClassName('MaintenanceSchedule')
class MaintenanceSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get productId => integer().references(Products, #id).nullable()();
  IntColumn get cycleMonths => integer()(); // 2, 3, or 6
  DateTimeColumn get lastMaintenanceDate => dateTime()();
  DateTimeColumn get nextMaintenanceDate => dateTime()();
  TextColumn get status => text().withDefault(
    const Constant('Active'),
  )(); // Active, Postponed, Cancelled
  DateTimeColumn get postponedUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Expense')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()(); // Rent, Salary, Transportation, etc.
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get description => text().nullable()();
  TextColumn get receiptImage => text().nullable()();
  IntColumn get createdBy => integer().references(Users, #id).nullable()();
}

@DataClassName('Supplier')
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('PurchaseInvoice')
class PurchaseInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get supplierId => integer().references(Suppliers, #id).nullable()();
  RealColumn get totalAmount => real()();
  TextColumn get notes => text().nullable()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PurchaseItem')
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseInvoiceId =>
      integer().references(PurchaseInvoices, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitCost => real()();
}

@DataClassName('InventoryAudit')
class InventoryAudits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  DateTimeColumn get auditDate => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SalesReturn')
class SalesReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(SalesInvoices, #id)();
  DateTimeColumn get returnDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmount => real()();
  TextColumn get notes => text().nullable()();
}

@DataClassName('SalesReturnItem')
class SalesReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(SalesReturns, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
}

@DataClassName('EmployeeProfile')
class EmployeeProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id).unique()();
  RealColumn get baseSalary => real().withDefault(const Constant(0.0))();
  DateTimeColumn get joiningDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('Active'))();
}

@DataClassName('PayrollTransaction')
class PayrollTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer().references(EmployeeProfiles, #id)();
  TextColumn get type => text()(); // BONUS, DEDUCTION, ADVANCE
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get description => text().nullable()();
  IntColumn get processedInPayrollId =>
      integer().nullable()(); // Linked to MonthlyPayroll when closed
}

@DataClassName('MonthlyPayroll')
class MonthlyPayrolls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer().references(EmployeeProfiles, #id)();
  TextColumn get monthYear => text()(); // e.g., '2023-10'
  RealColumn get baseSalary => real()();
  RealColumn get totalBonuses => real()();
  RealColumn get totalDeductions => real()();
  RealColumn get netSalary => real()();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('TechnicianCustodyItem')
class TechnicianCustody extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get technicianId => integer().references(Users, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('CashDrawerSession')
class CashDrawerSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  RealColumn get actualClosingBalance => real().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get openedBy => integer().references(Users, #id)();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
}

@DataClassName('CompanySetting')
class CompanySettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Stores the commission percentage for each technician.
/// Defaults to 10% if not set.
@DataClassName('TechnicianCommissionRate')
class TechnicianCommissionRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get technicianId => integer().references(Users, #id).unique()();
  RealColumn get commissionPercent =>
      real().withDefault(const Constant(10.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Records each time a technician hands over the collected money to the company
/// after completing a maintenance job.
@DataClassName('MaintenancePayment')
class MaintenancePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get requestId => integer().references(MaintenanceRequests, #id)();
  IntColumn get technicianId => integer().references(Users, #id)();
  RealColumn get totalCollected =>
      real()(); // Total money collected from customer
  RealColumn get commissionPercent =>
      real().withDefault(const Constant(10.0))();
  RealColumn get commissionAmount => real()(); // Technician's commission
  RealColumn get amountHandedOver => real()(); // Amount given to company
  DateTimeColumn get paymentDate =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}

/// Stores promotional offers/deals
@DataClassName('Offer')
class Offers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g., "Black Friday", "Summer Sale"
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get status => text().withDefault(
    const Constant('Active'),
  )(); // Active, Inactive, Expired
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get createdBy => integer().references(Users, #id).nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isBundle => boolean().withDefault(const Constant(false))();
}

/// Links products to offers with discount details
@DataClassName('OfferItem')
class OfferItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get offerId => integer().references(Offers, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get discountPercent => real().nullable()(); // e.g., 10 for 10% off
  RealColumn get discountedPrice => real()(); // Final price after discount
  IntColumn get quantity => integer()
      .nullable()(); // Max quantity available in offer, null = unlimited
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
