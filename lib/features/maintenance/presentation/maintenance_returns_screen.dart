import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../users/data/users_repository.dart';
import '../../products/presentation/products_providers.dart';
import '../domain/maintenance_printer.dart';
import 'maintenance_providers.dart';

import '../../inventory/presentation/custody_management_screen.dart';

// Provider to get all maintenance parts across all requests
final allMaintenancePartsProvider = StreamProvider<List<MaintenancePart>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.maintenanceParts).watch();
});

class MaintenanceReturnsScreen extends ConsumerWidget {
  const MaintenanceReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPartsAsync = ref.watch(allMaintenancePartsProvider);
    final requestsAsync = ref.watch(maintenanceRequestsStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final techniciansAsync = ref.watch(techniciansStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return AppLayout(
      title: 'مرتجعات الصيانة وحركة القطع',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBulkReturnDialog(context, ref),
        icon: const Icon(Icons.assignment_return),
        label: const Text('إنشاء مرتجع فني'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              isScrollable: true,
              tabs: [
                Tab(icon: Icon(Icons.handyman), text: 'إرجاع من الفني للمخزن'),
                Tab(icon: Icon(Icons.assignment_return), text: 'المرتجعات (سجل الطلبات)'),
                Tab(icon: Icon(Icons.inventory_2), text: 'كل القطع المنصرفة'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const CustodyManagementView(),
                  allPartsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('خطأ: $e')),
                    data: (allParts) {
                      final requests = requestsAsync.valueOrNull ?? [];
                      final customers = customersAsync.valueOrNull ?? [];
                      final technicians = techniciansAsync.valueOrNull ?? [];
                      final products = productsAsync.valueOrNull ?? [];

                      final returnedParts = allParts.where((p) => p.quantityOut > p.quantityUsed).toList();
                      return _buildReturnsList(context, returnedParts, requests, customers, technicians, products);
                    },
                  ),
                  allPartsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) => Center(child: Text('خطأ: $e')),
                    data: (allParts) {
                      final requests = requestsAsync.valueOrNull ?? [];
                      final customers = customersAsync.valueOrNull ?? [];
                      final technicians = techniciansAsync.valueOrNull ?? [];
                      final products = productsAsync.valueOrNull ?? [];

                      final dispensedParts = allParts.toList();
                      return _buildDispensedList(context, dispensedParts, requests, customers, technicians, products);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnsList(
    BuildContext context,
    List<MaintenancePart> parts,
    List<MaintenanceRequest> requests,
    List<Customer> customers,
    List<User> technicians,
    List<Product> products,
  ) {
    if (parts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_return_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0631\u062a\u062c\u0639\u0627\u062a \u0635\u064a\u0627\u0646\u0629 \u062d\u062a\u0649 \u0627\u0644\u0622\u0646.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Calculate total returned value
    double totalReturnedValue = 0;
    for (final part in parts) {
      totalReturnedValue += (part.quantityOut - part.quantityUsed) * part.unitPrice;
    }

    // Group parts by requestId so we can show a print button per request
    final Map<int, List<MaintenancePart>> grouped = {};
    for (final part in parts) {
      grouped.putIfAbsent(part.requestId, () => []).add(part);
    }

    return Column(
      children: [
        // Summary banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.teal.shade400],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryCard('\u0625\u062c\u0645\u0627\u0644\u064a \u0645\u0631\u062a\u062c\u0639\u0627\u062a', '${parts.length} \u0639\u0645\u0644\u064a\u0629', Icons.assignment_return),
              _summaryCard('\u0642\u064a\u0645\u0629 \u0627\u0644\u0645\u0631\u062a\u062c\u0639\u0627\u062a', '${totalReturnedValue.toStringAsFixed(1)} \u062c.\u0645', Icons.monetization_on),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: grouped.length,
            itemBuilder: (ctx, i) {
              final requestId = grouped.keys.elementAt(i);
              final reqParts = grouped[requestId]!;

              final req = requests.where((r) => r.id == requestId).firstOrNull;
              final customer = req != null ? customers.where((c) => c.id == req.customerId).firstOrNull : null;
              final tech = req?.technicianId != null ? technicians.where((t) => t.id == req!.technicianId).firstOrNull : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: const Icon(Icons.build, color: Colors.teal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\u0637\u0644\u0628 \u0635\u064a\u0627\u0646\u0629 #$requestId',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  '\u0627\u0644\u0639\u0645\u064a\u0644: ${customer?.name ?? '\u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641'} | \u0627\u0644\u0641\u0646\u064a: ${tech?.name ?? '\u063a\u064a\u0631 \u0645\u0639\u064a\u0646'}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // Print return invoice button
                          ElevatedButton.icon(
                            onPressed: () async {
                              final returnedItems = reqParts.map((part) {
                                final returnedQty = part.quantityOut - part.quantityUsed;
                                final product = products.where((p) => p.id == part.productId).firstOrNull;
                                return (
                                  productName: product?.name ?? '\u0645\u0646\u062a\u062c #${part.productId}',
                                  quantity: returnedQty,
                                  unitPrice: part.unitPrice,
                                );
                              }).where((i) => i.quantity > 0).toList();

                              if (returnedItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0642\u0637\u0639 \u0645\u0631\u062a\u062c\u0639\u0629 \u0644\u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628')),
                                );
                                return;
                              }

                              await MaintenancePrinter.printReturnInvoice(
                                requestId: requestId,
                                technicianName: tech?.name ?? '\u0627\u0644\u0641\u0646\u064a',
                                returnedItems: returnedItems,
                              );
                            },
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('\u0637\u0628\u0627\u0639\u0629 \u0625\u064a\u0635\u0627\u0644 \u0627\u0644\u0645\u0631\u062a\u062c\u0639'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      // Parts list
                      ...reqParts.map((part) {
                        final returnedQty = part.quantityOut - part.quantityUsed;
                        final returnedValue = returnedQty * part.unitPrice;
                        final product = products.where((p) => p.id == part.productId).firstOrNull;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product?.name ?? '\u0645\u0646\u062a\u062c #${part.productId}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              _qtyBadge('\u0645\u0646\u0635\u0631\u0641', part.quantityOut, Colors.orange),
                              const SizedBox(width: 6),
                              _qtyBadge('\u0645\u0633\u062a\u062e\u062f\u0645', part.quantityUsed, Colors.blue),
                              const SizedBox(width: 6),
                              _qtyBadge('\u0645\u0631\u062a\u062c\u0639', returnedQty, Colors.teal),
                              const SizedBox(width: 10),
                              Text(
                                '${returnedValue.toStringAsFixed(1)} \u062c.\u0645',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDispensedList(
    BuildContext context,
    List<MaintenancePart> parts,
    List<MaintenanceRequest> requests,
    List<Customer> customers,
    List<User> technicians,
    List<Product> products,
  ) {
    if (parts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لم يتم صرف أي قطع حتى الآن.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    double totalDispensedValue = 0;
    for (final part in parts) {
      totalDispensedValue += part.quantityOut * part.unitPrice;
    }
    double totalUsedValue = 0;
    for (final part in parts) {
      totalUsedValue += part.quantityUsed * part.unitPrice;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryCard('إجمالي عمليات الصرف', '${parts.length}', Icons.output),
              _summaryCard('قيمة المنصرف', '${totalDispensedValue.toStringAsFixed(1)} ج.م', Icons.money_off),
              _summaryCard('قيمة المستخدم فعلاً', '${totalUsedValue.toStringAsFixed(1)} ج.م', Icons.check_circle),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: parts.length,
            itemBuilder: (ctx, i) {
              final part = parts[i];
              final returnedQty = part.quantityOut - part.quantityUsed;

              final req = requests.where((r) => r.id == part.requestId).firstOrNull;
              final customer = req != null ? customers.where((c) => c.id == req.customerId).firstOrNull : null;
              final tech = req?.technicianId != null ? technicians.where((t) => t.id == req!.technicianId).firstOrNull : null;
              final product = products.where((p) => p.id == part.productId).firstOrNull;

              final isCompleted = req?.status == 'Completed';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? Colors.green.shade100 : Colors.orange.shade100,
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.pending,
                      color: isCompleted ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    product?.name ?? 'منتج #${part.productId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('طلب: #${part.requestId} | ${customer?.name ?? 'غير معروف'}'),
                      Text('الفني: ${tech?.name ?? 'لم يُعيَّن'}'),
                      Row(
                        children: [
                          _qtyBadge('منصرف', part.quantityOut, Colors.orange),
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            _qtyBadge('مستخدم', part.quantityUsed, Colors.blue),
                            if (returnedQty > 0) ...[
                              const SizedBox(width: 8),
                              _qtyBadge('مرتجع', returnedQty, Colors.teal),
                            ],
                          ] else ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('لم تكتمل الصيانة بعد', style: TextStyle(fontSize: 11, color: Colors.orange)),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(part.quantityOut * part.unitPrice).toStringAsFixed(1)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      Text(
                        'سعر الوحدة: ${part.unitPrice.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
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
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _qtyBadge(String label, int qty, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$label: $qty',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showBulkReturnDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const _BulkReturnDialog(),
    );
  }
}

class _BulkReturnDialog extends ConsumerStatefulWidget {
  const _BulkReturnDialog();

  @override
  ConsumerState<_BulkReturnDialog> createState() => _BulkReturnDialogState();
}

class _BulkReturnDialogState extends ConsumerState<_BulkReturnDialog> {
  int? _selectedTechnicianId;
  List<Map<String, dynamic>> _custodyItems = [];
  final Map<int, TextEditingController> _controllers = {};
  bool _isLoadingCustody = false;

  void _loadCustody(int technicianId) async {
    setState(() {
      _isLoadingCustody = true;
      _custodyItems = [];
      _controllers.clear();
    });

    try {
      final db = ref.read(databaseProvider);
      ref.invalidate(custodyProvider(technicianId)); // Invalidate cache to get fresh data
      final items = await ref.read(custodyProvider(technicianId).future);
      
      // Filter out items with 0 quantity so they don't clutter the return dialog
      final validItems = items.where((i) {
        final custody = i['custody'] as TechnicianCustodyItem;
        return custody.quantity > 0;
      }).toList();

      setState(() {
        _custodyItems = validItems;
        for (var item in validItems) {
          final custody = item['custody'] as TechnicianCustodyItem;
          _controllers[custody.id] = TextEditingController(text: '0');
        }
        _isLoadingCustody = false;
      });
    } catch (e) {
      setState(() => _isLoadingCustody = false);
    }
  }

  @override
  void dispose() {
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final techniciansAsync = ref.watch(techniciansStreamProvider);

    return AlertDialog(
      title: const Text('إنشاء مرتجع فني مجمع'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            techniciansAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const Text('خطأ في تحميل الفنيين'),
              data: (techs) => DropdownButtonFormField<int>(
                value: _selectedTechnicianId,
                decoration: const InputDecoration(labelText: 'اختر الفني', border: OutlineInputBorder()),
                items: techs.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                onChanged: (v) {
                  setState(() => _selectedTechnicianId = v);
                  if (v != null) _loadCustody(v);
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingCustody) const CircularProgressIndicator(),
            if (!_isLoadingCustody && _selectedTechnicianId != null)
              Expanded(
                child: _custodyItems.isEmpty
                    ? const Center(child: Text('لا توجد عهدة لهذا الفني.'))
                    : ListView.builder(
                        itemCount: _custodyItems.length,
                        itemBuilder: (context, index) {
                          final custody = _custodyItems[index]['custody'] as TechnicianCustodyItem;
                          final Product product = _custodyItems[index]['product'];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(product.name),
                              subtitle: Text('العهدة الحالية: ${custody.quantity}'),
                              trailing: SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: _controllers[custody.id],
                                  decoration: const InputDecoration(labelText: 'الكمية المرتجعة', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          onPressed: _selectedTechnicianId == null || _custodyItems.isEmpty ? null : () async {
            final db = ref.read(databaseProvider);
            
            bool hasAnyReturn = false;
            await db.transaction(() async {
              for (var item in _custodyItems) {
                final custody = item['custody'] as TechnicianCustodyItem;
                final Product product = item['product'];
                final ctrl = _controllers[custody.id];
                final qtyToReturn = int.tryParse(ctrl?.text ?? '0') ?? 0;
                
                if (qtyToReturn > 0 && qtyToReturn <= custody.quantity) {
                  hasAnyReturn = true;
                  // 1. Add to Main Stock
                  final currentProduct = await (db.select(db.products)..where((t) => t.id.equals(product.id))).getSingle();
                  await (db.update(db.products)..where((t) => t.id.equals(product.id)))
                      .write(ProductsCompanion(currentStock: drift.Value(currentProduct.currentStock + qtyToReturn)));
                      
                  // 2. Add movement record
                  await db.into(db.inventoryMovements).insert(
                    InventoryMovementsCompanion.insert(
                      productId: product.id,
                      type: 'IN_CUSTODY_RETURN',
                      quantity: qtyToReturn,
                      notes: drift.Value('مرتجع مجمع من عهدة الفني رقم $_selectedTechnicianId'),
                    )
                  );
                  
                  // 3. Deduct from Custody
                  if (custody.quantity - qtyToReturn <= 0) {
                    await (db.delete(db.technicianCustody)..where((t) => t.id.equals(custody.id))).go();
                  } else {
                    await (db.update(db.technicianCustody)..where((t) => t.id.equals(custody.id)))
                        .write(TechnicianCustodyCompanion(quantity: drift.Value(custody.quantity - qtyToReturn)));
                  }
                }
              }
            });

            if (mounted) {
              if (hasAnyReturn) {
                ref.invalidate(custodyProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل المرتجع وإضافته للمخزون'), backgroundColor: Colors.green));
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم إدخال كميات صحيحة للإرجاع'), backgroundColor: Colors.red));
              }
            }
          },
          child: const Text('حفظ المرتجع المجمع'),
        ),
      ],
    );
  }
}
