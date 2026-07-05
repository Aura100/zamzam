import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/database_provider.dart';
import '../domain/customer_statement_printer.dart';
import '../../../shared/services/excel_import_service.dart';
import 'customers_providers.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);

    return AppLayout(
      title: 'إدارة العملاء',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Toolbar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                Row(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'خيارات الإكسيل',
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'import',
                          child: Row(
                            children: [
                              Icon(Icons.upload_file, color: Colors.green),
                              SizedBox(width: 8),
                              Text('استيراد بيانات من Excel'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'template',
                          child: Row(
                            children: [
                              Icon(Icons.download, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('تحميل قالب Excel فارغ'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (String result) async {
                        final excelService = ref.read(excelImportServiceProvider);
                        if (result == 'import') {
                          final msg = await excelService.importCustomers();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          }
                        } else if (result == 'template') {
                          await excelService.exportTemplate();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ القالب بنجاح')));
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                        child: const Row(
                          children: [
                            Icon(Icons.file_present, color: Colors.white),
                            SizedBox(width: 8),
                            Text('إكسيل', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/customers/legacy'),
                      icon: const Icon(Icons.history),
                      label: const Text('إدخال عميل سابق'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/customers/add'),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة عميل جديد'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Customers List / Table
            Expanded(
              child: Card(
                child: customersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                  data: (customers) {
                    if (customers.isEmpty) {
                      return const Center(child: Text('لا يوجد عملاء. أضف عميل جديد.'));
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('رقم العميل')),
                            DataColumn(label: Text('الاسم')),
                            DataColumn(label: Text('رقم الهاتف')),
                            DataColumn(label: Text('العنوان')),
                            DataColumn(label: Text('الحالة')),
                            DataColumn(label: Text('إجراءات')),
                          ],
                          rows: customers.map((c) => DataRow(
                            cells: [
                              DataCell(Text(c.id.toString())),
                              DataCell(Text(c.name)),
                              DataCell(Text(c.phone1)),
                              DataCell(Text(c.address ?? '')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.status == 'Active' ? Colors.green.shade100 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    c.status == 'Active' ? 'نشط' : 'غير نشط',
                                    style: TextStyle(
                                      color: c.status == 'Active' ? Colors.green.shade900 : Colors.red.shade900,
                                    ),
                                  ),
                                )
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        context.push('/customers/add', extra: c);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.receipt_long, color: Colors.indigo),
                                      onPressed: () async {
                                        try {
                                          final db = ref.read(databaseProvider);
                                          final printer = CustomerStatementPrinter(db);
                                          await printer.printStatement(c);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('خطأ في طباعة كشف الحساب: $e'), backgroundColor: Colors.red),
                                            );
                                          }
                                        }
                                      },
                                      tooltip: 'كشف حساب العميل',
                                    ),
                                    if (c.phone1.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.wechat, color: Colors.green),
                                        onPressed: () async {
                                          final url = Uri.parse('https://wa.me/2${c.phone1}');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          }
                                        },
                                        tooltip: 'مراسلة واتساب',
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('تأكيد الحذف'),
                                              content: const Text('هل أنت متأكد من حذف هذا العميل؟'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('إلغاء'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            await ref.read(customersRepositoryProvider).deleteCustomer(c.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('تم حذف العميل بنجاح')),
                                              );
                                            }
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
}
