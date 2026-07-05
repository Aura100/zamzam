import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/excel_export_service.dart';
import 'sales_providers.dart';
import '../domain/receipt_printer.dart';
import '../../../shared/services/whatsapp_service.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);

    return AppLayout(
      title: 'إدارة المبيعات',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الفاتورة...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _exportInvoices(context, ref),
                      icon: const Icon(Icons.download),
                      label: const Text('تصدير إكسيل'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/create-invoice'),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('فاتورة مبيعات جديدة'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: invoicesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                  data: (invoices) {
                    final filtered = _searchQuery.isEmpty ? invoices : invoices.where((inv) {
                      return inv.invoiceNumber.toLowerCase().contains(_searchQuery) ||
                             inv.id.toString().contains(_searchQuery) ||
                             inv.customerId.toString().contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(child: Text(_searchQuery.isEmpty ? 'لا يوجد فواتير. قم بإنشاء فاتورة جديدة.' : 'لا توجد فواتير مطابقة للبحث'));
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('رقم الفاتورة')),
                            DataColumn(label: Text('تاريخ الفاتورة')),
                            DataColumn(label: Text('رقم العميل')),
                            DataColumn(label: Text('نوع الدفع')),
                            DataColumn(label: Text('الإجمالي')),
                            DataColumn(label: Text('إجراءات')),
                          ],
                          rows: filtered.map((inv) => DataRow(
                            cells: [
                              DataCell(Text(inv.invoiceNumber)),
                              DataCell(Text(inv.date.toString().substring(0, 10))),
                              DataCell(FutureBuilder(
                                future: ref.read(databaseProvider).select(ref.read(databaseProvider).customers).get(),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) return Text(inv.customerId.toString());
                                  final c = snap.data!.where((c) => c.id == inv.customerId).firstOrNull;
                                  return Text(c?.name ?? 'غير معروف');
                                },
                              )),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: inv.paymentType == 'CASH' ? Colors.green.shade100 : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    inv.paymentType == 'CASH' ? 'كاش' : 'قسط',
                                    style: TextStyle(
                                      color: inv.paymentType == 'CASH' ? Colors.green.shade900 : Colors.blue.shade900,
                                    ),
                                  ),
                                )
                              ),
                              DataCell(Text('${inv.totalAmount} ج.م')),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.print, color: Colors.blue),
                                      onPressed: () async {
                                        final db = ref.read(databaseProvider);
                                        final customer = await (db.select(db.customers)..where((t) => t.id.equals(inv.customerId))).getSingleOrNull();
                                        final items = await (db.select(db.invoiceItems)..where((t) => t.invoiceId.equals(inv.id))).get();
                                        // Load product names
                                        final allProducts = await db.select(db.products).get();
                                        final productNames = items.map((item) {
                                          final prod = allProducts.where((p) => p.id == item.productId).firstOrNull;
                                          return prod?.name ?? '';
                                        }).toList();
                                        // Load company settings
                                        final settingsList = await db.select(db.companySettings).get();
                                        final settings = { for (var s in settingsList) s.key: s.value };

                                        await ReceiptPrinter.printInvoice(
                                          inv,
                                          customer?.name ?? 'غير معروف',
                                          items,
                                          customerPhone: customer?.phone1 ?? '',
                                          customerAddress: customer?.address ?? '',
                                          productNames: productNames,
                                          companyName: settings['company_name'] ?? 'شركة زمزم للفلاتر',
                                          companyPhone: settings['company_phone'] ?? '01000000000',
                                          companyAddress: settings['company_address'] ?? 'القاهرة، مصر',
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chat, color: Colors.green),
                                      tooltip: 'إرسال واتساب',
                                      onPressed: () async {
                                        final db = ref.read(databaseProvider);
                                        final customer = await (db.select(db.customers)..where((t) => t.id.equals(inv.customerId))).getSingleOrNull();
                                        if (customer != null) {
                                          WhatsAppService.sendMessage(
                                            phone: customer.phone1,
                                            message: WhatsAppService.invoiceMessage(
                                              customerName: customer.name,
                                              invoiceNumber: inv.invoiceNumber,
                                              totalAmount: inv.totalAmount,
                                              paymentType: inv.paymentType,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                )
                              ),
                            ]
                          )).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportInvoices(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final invoices = await db.select(db.salesInvoices).get();
    
    final headers = ['معرف الفاتورة', 'رقم الفاتورة', 'معرف العميل', 'الخصم', 'الضريبة', 'مصاريف التوصيل', 'مصاريف التركيب', 'نوع الدفع', 'الإجمالي', 'التاريخ'];
    final rows = invoices.map((i) => [
      i.id,
      i.invoiceNumber,
      i.customerId,
      i.discount,
      i.tax,
      i.deliveryFees,
      i.installationFees,
      i.paymentType,
      i.totalAmount,
      i.date.toIso8601String(),
    ]).toList();

    final success = await ExcelExportService.exportToExcel(
      filename: 'سجل_الفواتير_${DateTime.now().day}_${DateTime.now().month}',
      headers: headers,
      rows: rows,
    );

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تصدير الفواتير بنجاح'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل تصدير الملف'), backgroundColor: Colors.red));
      }
    }
  }
}
