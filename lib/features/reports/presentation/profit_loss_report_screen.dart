import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';

class PLData {
  final double totalRevenues;
  final double totalCOGS;
  final double totalExpenses;
  final double totalPayroll;
  final double netProfit;

  PLData({
    required this.totalRevenues,
    required this.totalCOGS,
    required this.totalExpenses,
    required this.totalPayroll,
    required this.netProfit,
  });
}

final plReportProvider = FutureProvider.family<PLData, DateTimeRange>((ref, range) async {
  final db = ref.watch(databaseProvider);
  final start = range.start;
  final end = range.end;

  // 1. Total Revenues from Sales Invoices
  final salesInvoices = await (db.select(db.salesInvoices)
        ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerOrEqualValue(end)))
      .get();
  final totalRevenues = salesInvoices.fold(0.0, (sum, item) => sum + item.totalAmount);

  // 2. Cost of Goods Sold (COGS)
  // Join invoice items with products to get purchase price
  double totalCOGS = 0.0;
  if (salesInvoices.isNotEmpty) {
    final invoiceIds = salesInvoices.map((i) => i.id).toList();
    final itemsQuery = db.select(db.invoiceItems).join([
      drift.innerJoin(db.products, db.products.id.equalsExp(db.invoiceItems.productId)),
    ])..where(db.invoiceItems.invoiceId.isIn(invoiceIds));
    
    final itemsResult = await itemsQuery.get();
    for (final row in itemsResult) {
      final item = row.readTable(db.invoiceItems);
      final product = row.readTable(db.products);
      totalCOGS += (item.quantity * (product.purchasePrice ?? 0.0));
    }
  }

  // 3. Total Expenses
  final expenses = await (db.select(db.expenses)
        ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerOrEqualValue(end)))
      .get();
  final totalExpenses = expenses.fold(0.0, (sum, item) => sum + item.amount);

  // 4. Total Payroll
  final payroll = await (db.select(db.monthlyPayrolls)
        ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerOrEqualValue(end)))
      .get();
  final totalPayroll = payroll.fold(0.0, (sum, item) => sum + item.netSalary);

  final netProfit = totalRevenues - totalCOGS - totalExpenses - totalPayroll;

  return PLData(
    totalRevenues: totalRevenues,
    totalCOGS: totalCOGS,
    totalExpenses: totalExpenses,
    totalPayroll: totalPayroll,
    netProfit: netProfit,
  );
});

class ProfitLossReportScreen extends ConsumerStatefulWidget {
  const ProfitLossReportScreen({super.key});

  @override
  ConsumerState<ProfitLossReportScreen> createState() => _ProfitLossReportScreenState();
}

class _ProfitLossReportScreenState extends ConsumerState<ProfitLossReportScreen> {
  late DateTimeRange _dateRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(plReportProvider(_dateRange));

    return AppLayout(
      title: 'تقرير الأرباح والخسائر',
      child: Column(
        children: [
          // Date selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Colors.blue),
                title: const Text('الفترة المحددة لتقرير الدخل'),
                subtitle: Text(
                  'من: ${DateFormat('yyyy-MM-dd').format(_dateRange.start)}  إلى: ${DateFormat('yyyy-MM-dd').format(_dateRange.end)}',
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: _dateRange,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _dateRange = DateTimeRange(
                          start: picked.start,
                          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                        );
                      });
                    }
                  },
                  child: const Text('تغيير الفترة'),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('خطأ في تحميل التقرير: $e')),
              data: (data) {
                final profitColor = data.netProfit >= 0 ? Colors.green : Colors.red;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Overview cards
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.5,
                        children: [
                          _buildOverviewCard('إجمالي الإيرادات (المبيعات)', data.totalRevenues, Colors.blue),
                          _buildOverviewCard('تكلفة البضاعة المباعة (COGS)', data.totalCOGS, Colors.orange),
                          _buildOverviewCard('إجمالي المصاريف والرواتب', data.totalExpenses + data.totalPayroll, Colors.red),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Detailed Table
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'قائمة الدخل المبسطة',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 32),
                              _buildRow('(+) إجمالي المبيعات والإيرادات', data.totalRevenues, isBold: true),
                              const SizedBox(height: 12),
                              _buildRow('(-) تكلفة البضاعة المباعة (COGS)', -data.totalCOGS),
                              const Divider(),
                              _buildRow('مجمل الربح (Gross Profit)', data.totalRevenues - data.totalCOGS, isBold: true, color: Colors.blue.shade900),
                              const SizedBox(height: 12),
                              _buildRow('(-) المصاريف التشغيلية والإدارية', -data.totalExpenses),
                              const SizedBox(height: 12),
                              _buildRow('(-) الأجور والرواتب المصروفة', -data.totalPayroll),
                              const Divider(height: 32),
                              _buildRow(
                                'صافي الربح / الخسارة (Net Profit)',
                                data.netProfit,
                                isBold: true,
                                color: profitColor,
                                fontSize: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String title, double amount, MaterialColor color) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color.shade900, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${amount.toStringAsFixed(2)} ج.م',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double amount, {bool isBold = false, Color? color, double fontSize = 16}) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('${amount.toStringAsFixed(2)} ج.م', style: style),
      ],
    );
  }
}
