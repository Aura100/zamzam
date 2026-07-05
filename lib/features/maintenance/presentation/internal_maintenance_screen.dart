import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../users/data/users_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/presentation/products_providers.dart';
import '../domain/maintenance_printer.dart';
import '../../../core/database/database_provider.dart';
import 'maintenance_providers.dart';

class InternalMaintenanceScreen extends ConsumerWidget {
  const InternalMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(maintenanceRequestsStreamProvider);
    final techniciansAsync = ref.watch(techniciansStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    return AppLayout(
      title: 'الصيانة الداخلية (داخل الشركة)',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('طلبات الصيانة الداخلية', style: Theme.of(context).textTheme.titleLarge),
                ElevatedButton.icon(
                  onPressed: () => _showAddInternalRequestDialog(context, ref),
                  icon: const Icon(Icons.business_center),
                  label: const Text('صيانة داخلية جديدة'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border.all(color: Colors.purple.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.purple, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذه الصفحة مخصصة للصيانات التي يأتي بها العملاء إلى مقر الشركة.',
                      style: TextStyle(color: Colors.purple),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: requestsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                  data: (allRequests) {
                    final internalRequests = allRequests.where((r) => r.isInternal).toList();
                    final customers = customersAsync.valueOrNull ?? [];
                    final technicians = techniciansAsync.valueOrNull ?? [];

                    if (internalRequests.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('لا يوجد صيانات داخلية.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: internalRequests.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final req = internalRequests[index];
                        final customer = customers.where((c) => c.id == req.customerId).firstOrNull;
                        final tech = technicians.where((t) => t.id == req.technicianId).firstOrNull;

                        final statusColor = req.status == 'Completed'
                            ? Colors.green
                            : req.status == 'InProgress'
                                ? Colors.orange
                                : Colors.purple;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(Icons.business, color: statusColor),
                          ),
                          title: Text(
                            'صيانة داخلية #${req.id} - ${customer?.name ?? 'عميل #${req.customerId}'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المشكلة: ${req.issueDescription}'),
                              Text('تاريخ: ${req.scheduledDate.day}/${req.scheduledDate.month}/${req.scheduledDate.year}'),
                              if (req.scheduledTime != null)
                                Text('الوقت: ${req.scheduledTime}', style: const TextStyle(color: Colors.blue)),
                              Row(
                                children: [
                                  const Icon(Icons.engineering, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    tech != null ? tech.name : 'لم يُعيَّن فني',
                                    style: TextStyle(color: tech != null ? Colors.green : Colors.orange),
                                  ),
                                ],
                              ),
                              if (req.cost > 0)
                                Text('التكلفة: ${req.cost.toStringAsFixed(1)} ج.م',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: _buildTrailing(context, ref, req, customer, technicians, customers),
                        );
                      },
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

  Widget _buildTrailing(BuildContext context, WidgetRef ref, MaintenanceRequest req, Customer? customer, List<User> technicians, List<Customer> customers) {
    String techName = 'غير معين';
    final tech = technicians.where((t) => t.id == req.technicianId).firstOrNull;
    if (tech != null) techName = tech.name;

    if (req.status == 'Completed') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Chip(
            label: Text('مكتمل'),
            backgroundColor: Colors.green,
            labelStyle: TextStyle(color: Colors.white, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Colors.purple),
            tooltip: 'طباعة الفاتورة',
            onPressed: () async {
              if (customer == null) return;
              final parts = await ref.read(maintenancePartsProvider(req.id).future);
              final allProducts = ref.read(productsStreamProvider).valueOrNull ?? [];
              
              final db = ref.read(databaseProvider);
              final settingsList = await db.select(db.companySettings).get();
              final settings = { for (var s in settingsList) s.key: s.value };

              await MaintenancePrinter.printInvoice(
                request: req,
                customer: customer,
                parts: parts,
                allProducts: allProducts,
                technicianName: techName,
                companyName: settings['company_name'] ?? 'شركة زمزم للفلاتر',
              );
            },
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (req.technicianId == null)
          ElevatedButton.icon(
            onPressed: () => _showAssignTechDialog(context, ref, req),
            icon: const Icon(Icons.person_add, size: 14),
            label: const Text('تعيين فني', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          ),
        if (req.technicianId != null) ...[
          OutlinedButton.icon(
            onPressed: () => _showDispensePartDialog(context, ref, req),
            icon: const Icon(Icons.inventory, size: 14),
            label: const Text('صرف قطع', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () => _showCompleteDialog(context, ref, req),
            icon: const Icon(Icons.check, size: 14),
            label: const Text('إنهاء', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ],
    );
  }

  void _showAddInternalRequestDialog(BuildContext context, WidgetRef ref) {
    final issueCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    DateTime scheduledDate = DateTime.now();
    int? selectedCustomerId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final customersAsync = ref.watch(customersStreamProvider);

          return AlertDialog(
            title: const Text('صيانة داخلية جديدة'),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  customersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('خطأ في تحميل العملاء'),
                    data: (customers) => DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'اختر العميل *', border: OutlineInputBorder()),
                      items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      value: selectedCustomerId,
                      onChanged: (v) => setState(() => selectedCustomerId = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: issueCtrl,
                    decoration: const InputDecoration(labelText: 'وصف المشكلة / نوع الصيانة *', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today, color: Colors.purple),
                          title: Text('${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}'),
                          subtitle: const Text('التاريخ'),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: scheduledDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => scheduledDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: timeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الوقت (مثال: 10:00 ص)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCustomerId == null || issueCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء الحقول المطلوبة')));
                    return;
                  }
                  await ref.read(maintenanceRepositoryProvider).createRequest(
                    MaintenanceRequestsCompanion.insert(
                      customerId: selectedCustomerId!,
                      issueDescription: issueCtrl.text.trim(),
                      scheduledDate: scheduledDate,
                      scheduledTime: drift.Value(timeCtrl.text.isNotEmpty ? timeCtrl.text : null),
                      isInternal: const drift.Value(true),
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('تم إنشاء طلب الصيانة الداخلية'), backgroundColor: Colors.green));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignTechDialog(BuildContext context, WidgetRef ref, MaintenanceRequest req) {
    User? selectedTech;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final techniciansAsync = ref.watch(techniciansStreamProvider);

          return AlertDialog(
            title: const Text('تعيين فني للصيانة الداخلية'),
            content: SizedBox(
              width: 300,
              child: techniciansAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text('خطأ'),
                data: (techs) {
                  if (techs.isEmpty) return const Text('لا يوجد فنيين مسجلين. أضف مستخدماً بصلاحية Technician أولاً.');
                  return DropdownButtonFormField<User>(
                    decoration: const InputDecoration(labelText: 'اختر الفني', border: OutlineInputBorder()),
                    items: techs.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                    onChanged: (v) => selectedTech = v,
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedTech == null) return;
                  await ref.read(maintenanceRepositoryProvider).assignTechnician(req.id, selectedTech!.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعيين الفني'), backgroundColor: Colors.green));
                  }
                },
                child: const Text('تعيين'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDispensePartDialog(BuildContext context, WidgetRef ref, MaintenanceRequest req) {
    final qtyCtrl = TextEditingController(text: '1');
    Product? selectedProduct;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final productsAsync = ref.watch(productsStreamProvider);

          return AlertDialog(
            title: const Text('صرف قطع للصيانة الداخلية'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  productsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('خطأ'),
                    data: (products) => DropdownButtonFormField<Product>(
                      decoration: const InputDecoration(labelText: 'اختر القطعة/المنتج', border: OutlineInputBorder()),
                      items: products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (متاح: ${p.currentStock})'))).toList(),
                      onChanged: (v) => setState(() => selectedProduct = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (selectedProduct == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار منتج وكمية صحيحة'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (qty > selectedProduct!.currentStock) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('الكمية أكبر من المتاح!'), backgroundColor: Colors.red));
                    return;
                  }
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  await ref.read(maintenanceRepositoryProvider).dispensePart(req.id, selectedProduct!.id, qty, user.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الصرف'), backgroundColor: Colors.green));
                  }
                },
                child: const Text('صرف'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCompleteDialog(BuildContext context, WidgetRef ref, MaintenanceRequest req) {
    final costCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final actualUsedQuantities = <int, int>{};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء الصيانة الداخلية'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلب #${req.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('المشكلة: ${req.issueDescription}'),
                const Divider(),
                const Text('قطع الغيار المستخدمة:', style: TextStyle(fontWeight: FontWeight.bold)),
                Consumer(
                  builder: (context, ref, _) {
                    final partsAsync = ref.watch(maintenancePartsProvider(req.id));
                    final productsAsync = ref.watch(productsStreamProvider);
                    return partsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('خطأ'),
                      data: (parts) {
                        if (parts.isEmpty) return const Text('لم يتم صرف أي قطع.', style: TextStyle(color: Colors.grey));
                        return productsAsync.when(
                          loading: () => const SizedBox(),
                          error: (e, _) => const SizedBox(),
                          data: (products) => Column(
                            children: parts.map((part) {
                              final product = products.firstWhere((p) => p.id == part.productId);
                              actualUsedQuantities.putIfAbsent(part.id, () => part.quantityOut);
                              return Row(
                                children: [
                                  Expanded(child: Text(product.name)),
                                  Text('منصرف: ${part.quantityOut}'),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      initialValue: part.quantityOut.toString(),
                                      decoration: const InputDecoration(labelText: 'مستخدم فعلاً'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        int used = int.tryParse(val) ?? part.quantityOut;
                                        if (used > part.quantityOut) used = part.quantityOut;
                                        actualUsedQuantities[part.id] = used;
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(),
                const Text('تكلفة الخدمة:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(labelText: 'أجر الصيانة (ج.م)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final serviceCost = double.tryParse(costCtrl.text) ?? 0.0;
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              await ref.read(maintenanceRepositoryProvider).completeRequest(
                req.id, serviceCost, notesCtrl.text, actualUsedQuantities, user.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم إنهاء الصيانة الداخلية وإرجاع المتبقي للمخزون'), backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد الإنهاء'),
          ),
        ],
      ),
    );
  }
}
