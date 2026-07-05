import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class DashboardStats {
  final int totalCustomers;
  final int totalInvoicesToday;
  final double totalRevenueTodayCash;
  final double totalRevenueThisMonth;
  final double totalCollectionsToday;
  final int overdueInstallments;
  final int lowStockProducts;
  final List<Product> lowStockProductList;
  final double dailyRevenue;

  // Chart Data
  final List<double> weeklySales;
  final double collectionsCollected;
  final double collectionsPending;
  final double collectionsOverdue;

  DashboardStats({
    required this.totalCustomers,
    required this.totalInvoicesToday,
    required this.totalRevenueTodayCash,
    required this.totalRevenueThisMonth,
    required this.totalCollectionsToday,
    required this.overdueInstallments,
    required this.lowStockProducts,
    required this.lowStockProductList,
    required this.dailyRevenue,
    required this.weeklySales,
    required this.collectionsCollected,
    required this.collectionsPending,
    required this.collectionsOverdue,
  });
}

class DashboardRepository {
  final AppDatabase _db;

  DashboardRepository(this._db);

  Stream<DashboardStats> watchDashboardStats() {
    // We build a periodic stream by combining multiple queries
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) => _fetchStats())
      ..listen(null); // keep-alive trick
  }

  Future<DashboardStats> fetchStats() => _fetchStats();

  Future<DashboardStats> _fetchStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    // Total customers
    final customersQuery = _db.select(_db.customers)..where((t) => t.isDeleted.equals(false));
    final customers = await customersQuery.get();

    // Today's invoices
    final todayInvoices = await (_db.select(_db.salesInvoices)
      ..where((t) => t.date.isBiggerOrEqualValue(todayStart))).get();

    final cashToday = todayInvoices
        .where((i) => i.paymentType == 'CASH')
        .fold(0.0, (sum, i) => sum + i.totalAmount);

    // Today's returns
    final todayReturns = await (_db.select(_db.salesReturns)
      ..where((t) => t.returnDate.isBiggerOrEqualValue(todayStart))).get();
    final todayReturnsTotal = todayReturns.fold(0.0, (sum, r) => sum + r.totalAmount);

    // This month total revenue
    final monthInvoices = await (_db.select(_db.salesInvoices)
      ..where((t) => t.date.isBiggerOrEqualValue(monthStart))).get();
    final monthRevenue = monthInvoices.fold(0.0, (sum, i) => sum + i.totalAmount);

    // This month returns
    final monthReturns = await (_db.select(_db.salesReturns)
      ..where((t) => t.returnDate.isBiggerOrEqualValue(monthStart))).get();
    final monthReturnsTotal = monthReturns.fold(0.0, (sum, r) => sum + r.totalAmount);

    final netMonthRevenue = monthRevenue - monthReturnsTotal;
    final netDailyRevenue = todayInvoices.fold(0.0, (sum, i) => sum + i.totalAmount) - todayReturnsTotal;

    // Today's collections (paid installments today)
    final todayCollections = await (_db.select(_db.installments)
      ..where((t) => t.paidDate.isBiggerOrEqualValue(todayStart) & t.status.equals('Paid'))).get();
    final collectionsToday = todayCollections.fold(0.0, (sum, i) => sum + i.amount);

    final overdue = await (_db.select(_db.installments)
      ..where((t) => t.dueDate.isSmallerThanValue(todayStart) & t.status.equals('Pending'))).get();

    // Stats for Pie Chart
    final allInstallments = await _db.select(_db.installments).get();
    double collectedSum = 0;
    double pendingSum = 0;
    double overdueSum = 0;
    for (var i in allInstallments) {
      if (i.status == 'Paid') {
        collectedSum += i.amount;
      } else if (i.dueDate.isBefore(todayStart)) {
        overdueSum += (i.amount - i.partialPaidAmount);
        collectedSum += i.partialPaidAmount;
      } else {
        pendingSum += (i.amount - i.partialPaidAmount);
        collectedSum += i.partialPaidAmount;
      }
    }

    // Stats for Weekly Sales Chart
    List<double> weekly = List.filled(7, 0.0);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday % 7)); // Sunday start
    final weekInvoices = await (_db.select(_db.salesInvoices)
      ..where((t) => t.date.isBiggerOrEqualValue(weekStart))).get();
    
    for (var inv in weekInvoices) {
      final dayIndex = inv.date.weekday % 7; // 0 = Sunday, 1 = Monday... 6 = Saturday
      weekly[dayIndex] += inv.totalAmount;
    }

    // Low stock products
    final allProducts = await (_db.select(_db.products)
      ..where((t) => t.isDeleted.equals(false))).get();
    final lowStock = allProducts.where((p) => p.currentStock <= p.minStock).toList();

    return DashboardStats(
      totalCustomers: customers.length,
      totalInvoicesToday: todayInvoices.length,
      totalRevenueTodayCash: cashToday, // Note: We might also want to subtract cash returns here if needed, but we leave it as total collected today.
      totalRevenueThisMonth: netMonthRevenue,
      totalCollectionsToday: collectionsToday,
      overdueInstallments: overdue.length,
      lowStockProducts: lowStock.length,
      lowStockProductList: lowStock.take(10).toList(),
      dailyRevenue: netDailyRevenue,
      weeklySales: weekly,
      collectionsCollected: collectedSum,
      collectionsPending: pendingSum,
      collectionsOverdue: overdueSum,
    );
  }
}
