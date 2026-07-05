import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../database/app_database.dart';

class ArchiveProductSales {
  final String productName;
  final int quantity;
  final double revenue;

  ArchiveProductSales({
    required this.productName,
    required this.quantity,
    required this.revenue,
  });
}

class ArchiveAnalysisResult {
  final String archiveFileName;
  final int totalInvoices;
  final double totalSales;
  final int totalCustomers;
  final int totalProductsSold;
  final double totalDiscount;
  final int totalMaintenanceRequests;
  final int totalInternalMaintenance;
  final int totalExternalMaintenance;
  final double totalMaintenanceCommissionAmount;
  final int totalPayrollTransactions;
  final double totalPayrollAmount;
  final Map<String, double> dailySales;
  final List<ArchiveProductSales> topProducts;

  ArchiveAnalysisResult({
    required this.archiveFileName,
    required this.totalInvoices,
    required this.totalSales,
    required this.totalCustomers,
    required this.totalProductsSold,
    required this.totalDiscount,
    required this.totalMaintenanceRequests,
    required this.totalInternalMaintenance,
    required this.totalExternalMaintenance,
    required this.totalMaintenanceCommissionAmount,
    required this.totalPayrollTransactions,
    required this.totalPayrollAmount,
    required this.dailySales,
    required this.topProducts,
  });
}

class ArchiveAnalysisService {
  ArchiveAnalysisService._();

  static Future<ArchiveAnalysisResult> analyzeArchive(
    String archivePath,
  ) async {
    final archiveFile = File(archivePath);
    if (!await archiveFile.exists()) {
      throw FileSystemException('Archive file does not exist', archivePath);
    }

    final db = AppDatabase.open(archivePath);
    try {
      final invoices = await db.select(db.salesInvoices).get();
      final customers = await db.select(db.customers).get();
      final invoiceItems = await db.select(db.invoiceItems).get();
      final products = await db.select(db.products).get();
      final maintenanceRequests = await db.select(db.maintenanceRequests).get();
      final maintenancePayments = await db.select(db.maintenancePayments).get();
      final payrollTransactions = await db.select(db.payrollTransactions).get();

      final totalInvoices = invoices.length;
      final totalSales = invoices.fold<double>(
        0.0,
        (prev, inv) => prev + inv.totalAmount,
      );
      final totalCustomers = customers.length;
      final totalProductsSold = invoiceItems.fold<int>(
        0,
        (prev, item) => prev + item.quantity,
      );
      final totalDiscount = invoices.fold<double>(
        0.0,
        (prev, inv) => prev + inv.discount,
      );
      final totalMaintenanceRequests = maintenanceRequests.length;
      final totalInternalMaintenance = maintenanceRequests
          .where((request) => request.isInternal)
          .length;
      final totalExternalMaintenance = maintenanceRequests
          .where((request) => !request.isInternal)
          .length;
      final totalMaintenanceCommissionAmount = maintenancePayments.fold<double>(
        0.0,
        (prev, payment) => prev + payment.commissionAmount,
      );
      final totalPayrollTransactions = payrollTransactions.length;
      final totalPayrollAmount = payrollTransactions.fold<double>(
        0.0,
        (prev, transaction) => prev + transaction.amount,
      );

      final dailySales = <String, double>{};
      for (final invoice in invoices) {
        final dayKey =
            '${invoice.date.year}-${invoice.date.month.toString().padLeft(2, '0')}-${invoice.date.day.toString().padLeft(2, '0')}';
        dailySales[dayKey] = (dailySales[dayKey] ?? 0) + invoice.totalAmount;
      }

      final productMap = {for (final p in products) p.id: p.name};
      final productSales = <int, ArchiveProductSales>{};
      for (final item in invoiceItems) {
        final name = productMap[item.productId] ?? 'منتج #${item.productId}';
        final revenue = item.quantity * item.unitPrice;
        if (productSales.containsKey(item.productId)) {
          final existing = productSales[item.productId]!;
          productSales[item.productId] = ArchiveProductSales(
            productName: existing.productName,
            quantity: existing.quantity + item.quantity,
            revenue: existing.revenue + revenue,
          );
        } else {
          productSales[item.productId] = ArchiveProductSales(
            productName: name,
            quantity: item.quantity,
            revenue: revenue,
          );
        }
      }

      final topProducts = productSales.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      return ArchiveAnalysisResult(
        archiveFileName: p.basename(archivePath),
        totalInvoices: totalInvoices,
        totalSales: totalSales,
        totalCustomers: totalCustomers,
        totalProductsSold: totalProductsSold,
        totalDiscount: totalDiscount,
        totalMaintenanceRequests: totalMaintenanceRequests,
        totalInternalMaintenance: totalInternalMaintenance,
        totalExternalMaintenance: totalExternalMaintenance,
        totalMaintenanceCommissionAmount: totalMaintenanceCommissionAmount,
        totalPayrollTransactions: totalPayrollTransactions,
        totalPayrollAmount: totalPayrollAmount,
        dailySales: Map.fromEntries(
          dailySales.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        ),
        topProducts: topProducts.take(5).toList(),
      );
    } finally {
      await db.close();
    }
  }
}
