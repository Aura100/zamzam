import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../products/presentation/products_providers.dart';
import 'maintenance_providers.dart';

class MaintenanceSchedulesScreen extends ConsumerWidget {
  const MaintenanceSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(maintenanceSchedulesStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return AppLayout(
      title: 'جدولة الصيانة الدورية',
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'مستحقة الصيانة'),
                Tab(text: 'المؤجلون'),
                Tab(text: 'كل الجداول'),
              ],
            ),
            Expanded(
              child: schedulesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('خطأ: $e')),
                data: (schedules) {
                  final now = DateTime.now();
                  final customers = customersAsync.valueOrNull ?? [];
                  final products = productsAsync.valueOrNull ?? [];

                  final dueSchedules = schedules.where((s) => s.status == 'Active' && s.nextMaintenanceDate.isBefore(now)).toList();
                  final postponedSchedules = schedules.where((s) => s.status == 'Postponed').toList();

                  return TabBarView(
                    children: [
                      _buildScheduleList(context, ref, dueSchedules, customers, products, true),
                      _buildScheduleList(context, ref, postponedSchedules, customers, products, false),
                      _buildScheduleList(context, ref, schedules, customers, products, false, isAll: true),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScheduleDialog(context, ref),
        icon: const Icon(Icons.add_alarm),
        label: const Text('جدولة عميل'),
      ),
    );
  }

  Widget _buildScheduleList(BuildContext context, WidgetRef ref, List<MaintenanceSchedule> schedules, List<Customer> customers, List<Product> products, bool isDue, {bool isAll = false}) {
    if (schedules.isEmpty) {
      return const Center(child: Text('لا توجد بيانات.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (ctx, index) {
        final schedule = schedules[index];
        final customer = customers.where((c) => c.id == schedule.customerId).firstOrNull;
        final product = schedule.productId != null ? products.where((p) => p.id == schedule.productId).firstOrNull : null;
        
        final formatter = (DateTime d) => '${d.day}/${d.month}/${d.year}';
        
        return Card(
          child: ListTile(
            leading: Icon(Icons.history, color: isDue ? Colors.red : Colors.blue),
            title: Text('العميل: ${customer?.name ?? 'غير معروف'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('دورة الصيانة: كل ${schedule.cycleMonths} أشهر'),
                if (product != null) Text('المنتج: ${product.name}'),
                Text('تاريخ الاستحقاق: ${formatter(schedule.nextMaintenanceDate)}', style: TextStyle(color: isDue ? Colors.red : Colors.black, fontWeight: isDue ? FontWeight.bold : FontWeight.normal)),
                if (schedule.status == 'Postponed')
                  Text('مؤجل حتى: ${schedule.postponedUntil != null ? formatter(schedule.postponedUntil!) : 'غير محدد'}', style: const TextStyle(color: Colors.orange)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (schedule.status != 'Postponed' || isAll)
                  OutlinedButton.icon(
                    onPressed: () => _showPostponeDialog(context, ref, schedule),
                    icon: const Icon(Icons.access_time, size: 16),
                    label: const Text('تأجيل'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateRequestDialog(context, ref, schedule),
                  icon: const Icon(Icons.handyman, size: 16),
                  label: const Text('إنشاء طلب صيانة'),
                ),
                if (isAll)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('حذف الجدولة'),
                          content: const Text('هل أنت متأكد من حذف هذه الجدولة؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(maintenanceSchedulesRepositoryProvider).deleteSchedule(schedule.id);
                      }
                    },
                  )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddScheduleDialog(BuildContext context, WidgetRef ref) {
    int selectedCycle = 3;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final customersAsync = ref.watch(customersStreamProvider);
          final productsAsync = ref.watch(productsStreamProvider);
          Customer? selectedCustomer;
          Product? selectedProduct;

          return AlertDialog(
            title: const Text('إضافة عميل لجدول الصيانة الدورية'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  customersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('خطأ في تحميل العملاء'),
                    data: (customers) => DropdownButtonFormField<Customer>(
                      decoration: const InputDecoration(labelText: 'العميل *', border: OutlineInputBorder()),
                      items: customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                      onChanged: (v) => selectedCustomer = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                  productsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('خطأ في تحميل المنتجات'),
                    data: (products) => DropdownButtonFormField<Product>(
                      decoration: const InputDecoration(labelText: 'المنتج (اختياري)', border: OutlineInputBorder()),
                      items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                      onChanged: (v) => selectedProduct = v,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedCycle,
                    decoration: const InputDecoration(labelText: 'دورة الصيانة *', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('كل شهرين')),
                      DropdownMenuItem(value: 3, child: Text('كل 3 أشهر')),
                      DropdownMenuItem(value: 6, child: Text('كل 6 أشهر')),
                    ],
                    onChanged: (v) => setState(() => selectedCycle = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCustomer == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار عميل')));
                    return;
                  }
                  final now = DateTime.now();
                  final nextDate = DateTime(now.year, now.month + selectedCycle, now.day);
                  
                  await ref.read(maintenanceSchedulesRepositoryProvider).addSchedule(
                    MaintenanceSchedulesCompanion.insert(
                      customerId: selectedCustomer!.id,
                      productId: drift.Value(selectedProduct?.id),
                      cycleMonths: selectedCycle,
                      lastMaintenanceDate: now,
                      nextMaintenanceDate: nextDate,
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الجدولة بنجاح')));
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPostponeDialog(BuildContext context, WidgetRef ref, MaintenanceSchedule schedule) {
    DateTime postponeDate = DateTime.now().add(const Duration(days: 7));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('تأجيل الصيانة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر التاريخ الجديد الذي يفضله العميل للصيانة:'),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('${postponeDate.day}/${postponeDate.month}/${postponeDate.year}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: postponeDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => postponeDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(maintenanceSchedulesRepositoryProvider).postponeSchedule(schedule.id, postponeDate);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأجيل الصيانة')));
                }
              },
              child: const Text('تأكيد التأجيل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRequestDialog(BuildContext context, WidgetRef ref, MaintenanceSchedule schedule) {
    final issueCtrl = TextEditingController(text: 'صيانة دورية عادية');
    DateTime scheduledDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إنشاء طلب صيانة من الجدولة'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: issueCtrl,
                  decoration: const InputDecoration(labelText: 'وصف المشكلة / نوع الصيانة', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: Text('تاريخ الزيارة الفعلي: ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: scheduledDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => scheduledDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (issueCtrl.text.trim().isEmpty) return;
                
                final request = MaintenanceRequestsCompanion.insert(
                  customerId: schedule.customerId,
                  productId: drift.Value(schedule.productId),
                  issueDescription: issueCtrl.text.trim(),
                  scheduledDate: scheduledDate,
                );

                await ref.read(maintenanceSchedulesRepositoryProvider).createRequestFromSchedule(schedule.id, request);
                
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء طلب الصيانة وتحديث الجدولة بنجاح')));
                }
              },
              child: const Text('تأكيد وإنشاء الطلب'),
            ),
          ],
        ),
      ),
    );
  }
}
