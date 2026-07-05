import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../products/presentation/products_providers.dart';
import 'purchases_providers.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesStreamProvider);

    return AppLayout(
      title: 'إدارة المشتريات',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('فواتير المشتريات', style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showAddSupplierDialog(context, ref),
                      icon: const Icon(Icons.business),
                      label: const Text('مورد جديد'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showCreatePurchaseDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('فاتورة شراء جديدة'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: purchasesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (purchases) {
                    if (purchases.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('لا يوجد فواتير شراء. أضف فاتورة جديدة.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('رقم الفاتورة')),
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('الإجمالي')),
                          DataColumn(label: Text('المدفوع')),
                          DataColumn(label: Text('المتبقي')),
                          DataColumn(label: Text('ملاحظات')),
                          DataColumn(label: Text('إجراءات')),
                        ],
                        rows: purchases.map((p) {
                          final remaining = p.totalAmount - p.paidAmount;
                          return DataRow(cells: [
                            DataCell(Text(p.invoiceNumber)),
                            DataCell(Text('${p.date.day}/${p.date.month}/${p.date.year}')),
                            DataCell(Text('${p.totalAmount.toStringAsFixed(2)} ج.م')),
                            DataCell(Text('${p.paidAmount.toStringAsFixed(2)} ج.م',
                                style: TextStyle(color: p.paidAmount > 0 ? Colors.green.shade700 : Colors.grey))),
                            DataCell(Text('${remaining.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                    color: remaining > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                    fontWeight: FontWeight.bold))),
                            DataCell(Text(p.notes ?? '')),
                            DataCell(
                              remaining > 0
                                  ? TextButton.icon(
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text('تسجيل دفعة'),
                                      onPressed: () => _showPaymentDialog(context, ref, p, remaining),
                                    )
                                  : const Text('تم السداد ✓', style: TextStyle(color: Colors.green)),
                            ),
                          ]);
                        }).toList(),
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

  void _showAddSupplierDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مورد جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المورد *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(suppliersRepositoryProvider).addSupplier(
                SuppliersCompanion.insert(
                  name: nameCtrl.text.trim(),
                  phone: drift.Value(phoneCtrl.text.trim()),
                  address: drift.Value(addressCtrl.text.trim()),
                ),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة المورد'), backgroundColor: Colors.green));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showCreatePurchaseDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _CreatePurchaseDialog(ref: ref),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref, PurchaseInvoice invoice, double maxAmount) {
    final amountCtrl = TextEditingController(text: maxAmount.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل دفعة للمورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الفاتورة رقم: ${invoice.invoiceNumber}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0.0;
              if (amount <= 0 || amount > maxAmount) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المبلغ غير صحيح'), backgroundColor: Colors.red));
                return;
              }
              await ref.read(purchasesRepositoryProvider).recordPayment(invoice.id, amount);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة بنجاح'), backgroundColor: Colors.green));
              }
            },
            child: const Text('تأكيد الدفعة'),
          ),
        ],
      ),
    );
  }
}

class _CreatePurchaseDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _CreatePurchaseDialog({required this.ref});

  @override
  ConsumerState<_CreatePurchaseDialog> createState() => _CreatePurchaseDialogState();
}

class _CreatePurchaseDialogState extends ConsumerState<_CreatePurchaseDialog> {
  final Map<int, int> _quantities = {}; // productId -> quantity
  final Map<int, double> _costs = {}; // productId -> unit cost
  final _notesCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final suppliersAsync = ref.watch(suppliersStreamProvider);

    Supplier? selectedSupplier;

    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('إنشاء فاتورة شراء'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: Column(
            children: [
              suppliersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text('خطأ في تحميل الموردين'),
                data: (suppliers) => DropdownButtonFormField<Supplier>(
                  decoration: const InputDecoration(labelText: 'المورد (اختياري)', border: OutlineInputBorder()),
                  items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                  onChanged: (v) => setState(() => selectedSupplier = v),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Expanded(
                child: productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (products) => ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = products[i];
                      return ListTile(
                        dense: true,
                        title: Text(p.name),
                        subtitle: Text('المخزون: ${p.currentStock}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                decoration: const InputDecoration(labelText: 'سعر', isDense: true, border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => _costs[p.id] = double.tryParse(v) ?? 0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                decoration: const InputDecoration(labelText: 'كمية', isDense: true, border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => _quantities[p.id] = int.tryParse(v) ?? 0),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final items = _quantities.entries
                  .where((e) => e.value > 0)
                  .map((e) => PurchaseItemsCompanion.insert(
                        purchaseInvoiceId: 0,
                        productId: e.key,
                        quantity: e.value,
                        unitCost: _costs[e.key] ?? 0.0,
                      ))
                  .toList();

              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم تحدد أي منتجات')));
                return;
              }

              final total = items.fold(0.0, (sum, item) => sum + (item.unitCost.value * item.quantity.value));

              await ref.read(purchasesRepositoryProvider).createPurchase(
                invoice: PurchaseInvoicesCompanion.insert(
                  invoiceNumber: 'PO-${DateTime.now().millisecondsSinceEpoch}',
                  totalAmount: total,
                  supplierId: drift.Value(selectedSupplier?.id),
                  notes: drift.Value(_notesCtrl.text),
                ),
                items: items,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل فاتورة الشراء وتحديث المخزون'), backgroundColor: Colors.green));
              }
            },
            child: const Text('حفظ الفاتورة'),
          ),
        ],
      ),
    );
  }
}
