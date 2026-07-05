import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../sales/presentation/sales_providers.dart';
import '../../collections/presentation/collections_providers.dart';
import '../../expenses/presentation/expenses_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLayout(
      title: 'التقارير والإحصائيات',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.0,
          children: [
            _buildReportCard(context, 'تقرير المبيعات', Icons.point_of_sale, Colors.blue, () => _showSalesReport(context, ref)),
            _buildReportCard(context, 'تقرير التحصيلات', Icons.money, Colors.green, () => _showCollectionsReport(context, ref)),
            _buildReportCard(context, 'تقرير المصروفات', Icons.money_off, Colors.red, () => _showExpensesReport(context, ref)),
            _buildReportCard(context, 'تقرير المخزون', Icons.inventory, Colors.orange, () => context.go('/products')),
            _buildReportCard(context, 'عمولات الفنيين', Icons.engineering, Colors.blueGrey, () => context.go('/commissions-report')),
            _buildReportCard(context, 'تقرير الأرباح والخسائر', Icons.analytics, Colors.indigo, () => context.go('/profit-loss')),
            _buildReportCard(context, 'أقساط متأخرة', Icons.warning, Colors.purple, () => context.go('/collections')),
            _buildReportCard(context, 'إدارة المستخدمين', Icons.people_alt, Colors.teal, () => context.go('/users')),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showSalesReport(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.read(invoicesStreamProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقرير المبيعات'),
        content: SizedBox(
          width: 700,
          height: 500,
          child: invoicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (invoices) {
              final cashTotal = invoices.where((i) => i.paymentType == 'CASH').fold(0.0, (s, i) => s + i.totalAmount);
              final instTotal = invoices.where((i) => i.paymentType == 'INSTALLMENT').fold(0.0, (s, i) => s + i.totalAmount);
              return Column(
                children: [
                  Row(
                    children: [
                      _summaryChip('إجمالي كاش', '${cashTotal.toStringAsFixed(0)} ج.م', Colors.green),
                      const SizedBox(width: 12),
                      _summaryChip('إجمالي تقسيط', '${instTotal.toStringAsFixed(0)} ج.م', Colors.blue),
                      const SizedBox(width: 12),
                      _summaryChip('عدد الفواتير', '${invoices.length}', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('رقم الفاتورة')),
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('نوع الدفع')),
                          DataColumn(label: Text('الإجمالي')),
                        ],
                        rows: invoices.map((i) => DataRow(cells: [
                          DataCell(Text(i.invoiceNumber)),
                          DataCell(Text('${i.date.day}/${i.date.month}/${i.date.year}')),
                          DataCell(Text(i.paymentType == 'CASH' ? 'كاش' : 'تقسيط')),
                          DataCell(Text('${i.totalAmount.toStringAsFixed(2)} ج.م')),
                        ])).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _showCollectionsReport(BuildContext context, WidgetRef ref) {
    final overdueAsync = ref.read(overdueInstallmentsProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقرير الأقساط المتأخرة'),
        content: SizedBox(
          width: 700,
          height: 500,
          child: overdueAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (installments) {
              final totalOverdue = installments.fold(0.0, (s, i) => s + (i.installment.amount - i.installment.partialPaidAmount));
              return Column(
                children: [
                  _summaryChip('إجمالي المتأخر', '${totalOverdue.toStringAsFixed(0)} ج.م', Colors.red),
                  const SizedBox(height: 12),
                  Expanded(
                    child: installments.isEmpty
                        ? const Center(child: Text('لا يوجد أقساط متأخرة 🎉'))
                        : SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('رقم العقد')),
                                DataColumn(label: Text('اسم العميل')),
                                DataColumn(label: Text('تاريخ الاستحقاق')),
                                DataColumn(label: Text('المبلغ المتأخر')),
                              ],
                              rows: installments.map((i) => DataRow(cells: [
                                DataCell(Text('${i.installment.contractId}')),
                                DataCell(Text(i.customer.name)),
                                DataCell(Text('${i.installment.dueDate.day}/${i.installment.dueDate.month}/${i.installment.dueDate.year}')),
                                DataCell(Text('${(i.installment.amount - i.installment.partialPaidAmount).toStringAsFixed(2)} ج.م')),
                              ])).toList(),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showExpensesReport(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.read(expensesStreamProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقرير المصروفات'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
            data: (expenses) {
              final total = expenses.fold(0.0, (s, e) => s + e.amount);
              final byCategory = <String, double>{};
              for (final e in expenses) {
                byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
              }
              return Column(
                children: [
                  _summaryChip('إجمالي المصروفات', '${total.toStringAsFixed(0)} ج.م', Colors.red),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // By category summary
                          ...byCategory.entries.map((e) => ListTile(
                            title: Text(e.key),
                            trailing: Text('${e.value.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
