import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../users/data/users_repository.dart';
import '../../../core/database/database_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../products/presentation/products_providers.dart';
import '../domain/maintenance_printer.dart';
import 'maintenance_providers.dart';
import '../../../shared/services/whatsapp_service.dart';
import '../../reports/domain/commission_utils.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(maintenanceRequestsStreamProvider);
    final techniciansAsync = ref.watch(
      techniciansStreamProvider,
    ); // Need this for tech names

    return AppLayout(
      title: 'إدارة الصيانة',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طلبات الصيانة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddRequestDialog(context, ref),
                  icon: const Icon(Icons.handyman),
                  label: const Text('طلب صيانة جديد'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: requestsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                  data: (requests) {
                    if (requests.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.build_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'لا يوجد طلبات صيانة.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final statusColor = req.status == 'Completed'
                            ? Colors.green
                            : req.status == 'InProgress'
                            ? Colors.orange
                            : Colors.blue;

                        // Find technician name
                        String techName = 'لم يتم التعيين';
                        if (req.technicianId != null) {
                          final techList = techniciansAsync.valueOrNull ?? [];
                          final tech = techList
                              .where((u) => u.id == req.technicianId)
                              .firstOrNull;
                          if (tech != null) techName = tech.name;
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(Icons.build, color: statusColor),
                          ),
                          title: Text(
                            'طلب صيانة #${req.id} - عميل ${req.customerId}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المشكلة: ${req.issueDescription}'),
                              Text(
                                'الموعد: ${req.scheduledDate.day}/${req.scheduledDate.month}/${req.scheduledDate.year}',
                              ),
                              Text(
                                'الفني: $techName',
                                style: const TextStyle(color: Colors.blue),
                              ),
                              if (req.cost > 0)
                                Text(
                                  'التكلفة النهائية: ${req.cost} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.chat,
                                  color: Colors.green,
                                ),
                                tooltip: 'إرسال واتساب',
                                onPressed: () {
                                  final customerList =
                                      ref
                                          .read(customersStreamProvider)
                                          .valueOrNull ??
                                      [];
                                  final customer = customerList
                                      .where((c) => c.id == req.customerId)
                                      .firstOrNull;
                                  if (customer != null &&
                                      customer.phone1.isNotEmpty) {
                                    WhatsAppService.sendMessage(
                                      phone: customer.phone1,
                                      message:
                                          WhatsAppService.maintenanceConfirmationMessage(
                                            customerName: customer.name,
                                            date:
                                                '${req.scheduledDate.day}/${req.scheduledDate.month}/${req.scheduledDate.year}',
                                            issueDescription:
                                                req.issueDescription,
                                          ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'لا يوجد رقم هاتف للعميل',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              if (req.status != 'Completed') ...[
                                if (req.technicianId == null)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showAssignTechnicianDialog(
                                          context,
                                          ref,
                                          req,
                                        ),
                                    icon: const Icon(
                                      Icons.person_add,
                                      size: 16,
                                    ),
                                    label: const Text('تعيين فني'),
                                  ),
                                if (req.technicianId != null) ...[
                                  OutlinedButton.icon(
                                    onPressed: () => _showDispensePartDialog(
                                      context,
                                      ref,
                                      req,
                                    ),
                                    icon: const Icon(Icons.inventory, size: 16),
                                    label: const Text('صرف قطع'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showCompleteDialog(context, ref, req),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('إنهاء الصيانة'),
                                  ),
                                ],
                              ] else ...[
                                const Chip(
                                  label: Text('مكتمل'),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.print,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'طباعة فاتورة الصيانة',
                                  onPressed: () async {
                                    final customerList =
                                        ref
                                            .read(customersStreamProvider)
                                            .valueOrNull ??
                                        [];
                                    final customer = customerList.firstWhere(
                                      (c) => c.id == req.customerId,
                                    );
                                    final parts = await ref.read(
                                      maintenancePartsProvider(req.id).future,
                                    );
                                    final allProducts =
                                        ref
                                            .read(productsStreamProvider)
                                            .valueOrNull ??
                                        [];
                                    final db = ref.read(databaseProvider);
                                    final settingsList = await db
                                        .select(db.companySettings)
                                        .get();
                                    final settings = {
                                      for (var s in settingsList)
                                        s.key: s.value,
                                    };
                                    await MaintenancePrinter.printInvoice(
                                      request: req,
                                      customer: customer,
                                      parts: parts,
                                      allProducts: allProducts,
                                      technicianName: techName,
                                      companyName:
                                          settings['company_name'] ??
                                          'شركة زمزم للفلاتر',
                                      companyPhone:
                                          settings['company_phone'] ?? '',
                                      companyAddress:
                                          settings['company_address'] ?? '',
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.attach_money,
                                    color: Colors.orange,
                                  ),
                                  tooltip: 'تسليم المال للشركة',
                                  onPressed: () => _showPaymentHandoverDialog(
                                    context,
                                    ref,
                                    req,
                                    techName,
                                  ),
                                ),
                              ],
                            ],
                          ),
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

  void _showAddRequestDialog(BuildContext context, WidgetRef ref) {
    final issueCtrl = TextEditingController();
    DateTime scheduledDate = DateTime.now().add(const Duration(days: 1));
    int? selectedCustomerId; // Use ID instead of Customer object

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final customersAsync = ref.watch(customersStreamProvider);

          return AlertDialog(
            title: const Text('طلب صيانة جديد'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  customersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => const Text('خطأ في تحميل العملاء'),
                    data: (customers) => DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'اختر العميل *',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedCustomerId,
                      items: customers
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedCustomerId = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: issueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'وصف المشكلة *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                    ),
                    title: Text(
                      'موعد الزيارة: ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}',
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: scheduledDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null)
                        setState(() => scheduledDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCustomerId == null ||
                      issueCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى ملء جميع الحقول')),
                    );
                    return;
                  }
                  await ref
                      .read(maintenanceRepositoryProvider)
                      .createRequest(
                        MaintenanceRequestsCompanion.insert(
                          customerId: selectedCustomerId!,
                          issueDescription: issueCtrl.text.trim(),
                          scheduledDate: scheduledDate,
                        ),
                      );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تسجيل طلب الصيانة'),
                        backgroundColor: Colors.green,
                      ),
                    );
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

  void _showAssignTechnicianDialog(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRequest req,
  ) {
    User? selectedTech;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final techniciansAsync = ref.watch(techniciansStreamProvider);

          return AlertDialog(
            title: const Text('تعيين فني للصيانة'),
            content: SizedBox(
              width: 300,
              child: techniciansAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text('خطأ في تحميل الفنيين'),
                data: (techs) {
                  if (techs.isEmpty)
                    return const Text(
                      'لا يوجد فنيين مسجلين في النظام. قم بإضافة مستخدم بصلاحية فني أولاً.',
                    );
                  return DropdownButtonFormField<User>(
                    decoration: const InputDecoration(
                      labelText: 'اختر الفني',
                      border: OutlineInputBorder(),
                    ),
                    items: techs
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        )
                        .toList(),
                    onChanged: (v) => selectedTech = v,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedTech == null) return;
                  await ref
                      .read(maintenanceRepositoryProvider)
                      .assignTechnician(req.id, selectedTech!.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تعيين الفني بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
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

  void _showDispensePartDialog(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRequest req,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _MultiDispenseDialog(req: req),
    );
  }

  void _showCompleteDialog(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRequest req,
  ) {
    final costCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final actualUsedQuantities = <int, int>{}; // Map of partId -> usedQty

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء طلب الصيانة'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب رقم #${req.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('المشكلة: ${req.issueDescription}'),
                const Divider(),
                const Text(
                  'قطع الغيار المنصرفة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final partsAsync = ref.watch(
                      maintenancePartsProvider(req.id),
                    );
                    final productsAsync = ref.watch(productsStreamProvider);

                    return partsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('خطأ في تحميل القطع'),
                      data: (parts) {
                        if (parts.isEmpty)
                          return const Text(
                            'لم يتم صرف أي قطع لهذا الطلب.',
                            style: TextStyle(color: Colors.grey),
                          );

                        return productsAsync.when(
                          loading: () => const SizedBox(),
                          error: (e, _) => const SizedBox(),
                          data: (products) {
                            return Column(
                              children: parts.map((part) {
                                final product = products.firstWhere(
                                  (p) => p.id == part.productId,
                                );
                                // Initialize max used to quantity out
                                actualUsedQuantities.putIfAbsent(
                                  part.id,
                                  () => part.quantityOut,
                                );
                                return Row(
                                  children: [
                                    Expanded(child: Text(product.name)),
                                    Text('المنصرف: ${part.quantityOut}'),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue: part.quantityOut
                                            .toString(),
                                        decoration: const InputDecoration(
                                          labelText: 'المُستخدم فعلياً',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          int used =
                                              int.tryParse(val) ??
                                              part.quantityOut;
                                          if (used > part.quantityOut)
                                            used = part.quantityOut;
                                          if (used < 0) used = 0;
                                          actualUsedQuantities[part.id] = used;
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const Divider(),
                const Text(
                  'التكاليف الإضافية (مصنعية الفني والانتقالات):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المصنعية (ج.م)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final serviceCost = double.tryParse(costCtrl.text) ?? 0.0;
              final currentUser = ref.read(currentUserProvider);
              if (currentUser == null) return;

              await ref
                  .read(maintenanceRepositoryProvider)
                  .completeRequest(
                    req.id,
                    serviceCost,
                    notesCtrl.text,
                    actualUsedQuantities,
                    currentUser.id,
                  );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم إنهاء الصيانة وإرجاع القطع الزائدة للمخزون',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد الإنهاء'),
          ),
        ],
      ),
    );
  }

  // ─── PAYMENT HANDOVER DIALOG ──────────────────────────────────────────────
  void _showPaymentHandoverDialog(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRequest req,
    String techName,
  ) {
    final collectedCtrl = TextEditingController(
      text: req.cost.toStringAsFixed(2),
    );
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('تسليم المال للشركة'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: FutureBuilder<double>(
                future: () async {
                  final db = ref.read(databaseProvider);
                  if (req.technicianId == null) return 10.0;
                  final rate =
                      await (db.select(db.technicianCommissionRates)..where(
                            (t) => t.technicianId.equals(req.technicianId!),
                          ))
                          .getSingleOrNull();
                  return rate?.commissionPercent ?? 10.0;
                }(),
                builder: (context, snapshot) {
                  final commPct = snapshot.data ?? 10.0;
                  final collected =
                      double.tryParse(collectedCtrl.text) ?? req.cost;
                  final commission = calculateCommissionAmount(
                    collected,
                    commPct,
                  );
                  final handover = collected - commission;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلب الصيانة #${req.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الفني: $techName',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: collectedCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ المحصّل من العميل (ج.م)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payments),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 16),
                      // Commission breakdown
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          children: [
                            _payRow(
                              'المبلغ الإجمالي المحصّل',
                              '${collected.toStringAsFixed(2)} ج.م',
                              Colors.black87,
                            ),
                            const Divider(),
                            _payRow(
                              'عمولة الفني (${commPct.toStringAsFixed(1)}%)',
                              '${commission.toStringAsFixed(2)} ج.م',
                              Colors.orange,
                            ),
                            const Divider(),
                            _payRow(
                              'المبلغ المسلّم للشركة',
                              '${handover.toStringAsFixed(2)} ج.م',
                              Colors.green,
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('تأكيد التسليم'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  double commPct = 10.0;
                  if (req.technicianId != null) {
                    final rate =
                        await (db.select(db.technicianCommissionRates)..where(
                              (t) => t.technicianId.equals(req.technicianId!),
                            ))
                            .getSingleOrNull();
                    commPct = rate?.commissionPercent ?? 10.0;
                  }
                  final collected =
                      double.tryParse(collectedCtrl.text) ?? req.cost;
                  final commission = calculateCommissionAmount(
                    collected,
                    commPct,
                  );
                  final handover = collected - commission;

                  await db
                      .into(db.maintenancePayments)
                      .insert(
                        MaintenancePaymentsCompanion.insert(
                          requestId: req.id,
                          technicianId: req.technicianId ?? 0,
                          totalCollected: collected,
                          commissionPercent: drift.Value(commPct),
                          commissionAmount: commission,
                          amountHandedOver: handover,
                          notes: drift.Value(
                            notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                          ),
                        ),
                      );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم تسجيل تسليم ${handover.toStringAsFixed(2)} ج.م للشركة ✅',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _payRow(
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-product dispense dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single row in the dispense list
class _DispenseLine {
  Product? product;
  final TextEditingController qtyController;

  _DispenseLine() : qtyController = TextEditingController(text: '1');

  void dispose() => qtyController.dispose();
}

class _MultiDispenseDialog extends ConsumerStatefulWidget {
  final MaintenanceRequest req;
  const _MultiDispenseDialog({required this.req});

  @override
  ConsumerState<_MultiDispenseDialog> createState() =>
      _MultiDispenseDialogState();
}

class _MultiDispenseDialogState extends ConsumerState<_MultiDispenseDialog> {
  final List<_DispenseLine> _lines = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _lines.add(_DispenseLine()); // Start with one row
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_DispenseLine()));
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final products = ref.read(productsStreamProvider).valueOrNull ?? [];

    // Validate
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('السطر ${i + 1}: يرجى اختيار منتج')),
        );
        return;
      }
      final qty = int.tryParse(line.qtyController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('السطر ${i + 1}: الكمية يجب أن تكون أكبر من صفر')),
        );
        return;
      }
      // Get fresh stock from provider list
      final freshProduct = products.where((p) => p.id == line.product!.id).firstOrNull;
      final available = freshProduct?.currentStock ?? line.product!.currentStock;
      if (qty > available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('السطر ${i + 1}: الكمية المطلوبة (${qty}) أكبر من المتاح في المخزن (${available})'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(maintenanceRepositoryProvider);
      for (final line in _lines) {
        final qty = int.tryParse(line.qtyController.text) ?? 0;
        await repo.dispensePart(
          widget.req.id,
          line.product!.id,
          qty,
          currentUser.id,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم صرف ${_lines.length} قطعة بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory, color: Colors.blue),
          const SizedBox(width: 8),
          Text('صرف قطع - طلب #${widget.req.id}'),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('خطأ في تحميل المنتجات: $e')),
          data: (products) {
            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'يمكنك إضافة عدة منتجات وصرفها دفعة واحدة',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('إضافة منتج'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Lines list
                Expanded(
                  child: _lines.isEmpty
                      ? const Center(child: Text('اضغط "إضافة منتج" لبدء الصرف'))
                      : ListView.builder(
                          itemCount: _lines.length,
                          itemBuilder: (ctx, i) {
                            final line = _lines[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    // Product number badge
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.blue.shade100,
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Product dropdown
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<Product>(
                                        value: line.product,
                                        decoration: const InputDecoration(
                                          labelText: 'المنتج',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        isExpanded: true,
                                        items: products
                                            .map(
                                              (p) => DropdownMenuItem(
                                                value: p,
                                                child: Text(
                                                  '${p.name} (${p.currentStock})',
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) =>
                                            setState(() => line.product = v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Quantity field
                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: line.qtyController,
                                        decoration: const InputDecoration(
                                          labelText: 'الكمية',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Remove button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                      onPressed: _lines.length > 1
                                          ? () => _removeLine(i)
                                          : null,
                                      tooltip: 'حذف هذا السطر',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(_isSubmitting ? 'جارٍ الصرف...' : 'تأكيد الصرف (${_lines.length})'),
        ),
      ],
    );
  }
}

