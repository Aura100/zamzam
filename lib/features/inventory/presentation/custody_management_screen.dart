import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';

final custodyProvider = StreamProvider.family<List<Map<String, dynamic>>, int>((ref, technicianId) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.technicianCustody)
      ..where((t) => t.technicianId.equals(technicianId));
      
  return query.join([
    drift.innerJoin(db.products, db.products.id.equalsExp(db.technicianCustody.productId)),
  ]).watch().map((results) {
    return results.map((r) {
      return {
        'custody': r.readTable(db.technicianCustody),
        'product': r.readTable(db.products),
      };
    }).toList();
  });
});

class CustodyManagementScreen extends StatelessWidget {
  const CustodyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppLayout(
      title: 'عُهد الفنيين',
      child: CustodyManagementView(),
    );
  }
}

class CustodyManagementView extends ConsumerStatefulWidget {
  const CustodyManagementView({super.key});

  @override
  ConsumerState<CustodyManagementView> createState() => _CustodyManagementViewState();
}

class _CustodyManagementViewState extends ConsumerState<CustodyManagementView> {
  int? _selectedTechnicianId;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<List<User>>(
            future: (db.select(db.users)..where((t) => t.role.equals('Technician') | t.role.equals('Administrator'))).get(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final techs = snap.data!;
              return DropdownButtonFormField<int>(
                value: _selectedTechnicianId,
                decoration: const InputDecoration(labelText: 'اختر الفني'),
                items: techs.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _selectedTechnicianId = v),
              );
            },
          ),
        ),
        if (_selectedTechnicianId != null)
          Expanded(
            child: ref.watch(custodyProvider(_selectedTechnicianId!)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('خطأ: $e')),
              data: (items) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () => _showIssueCustodyDialog(context, _selectedTechnicianId!),
                          icon: const Icon(Icons.add_box),
                          label: const Text('صرف عهدة جديدة للفني'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final custody = items[index]['custody'] as TechnicianCustodyItem;
                          final Product product = items[index]['product'];
                          final quantity = custody.quantity;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(product.name),
                              subtitle: Text('الكمية الحالية في العهدة: $quantity'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.keyboard_return, size: 18),
                                    label: const Text('استرجاع للمخزن'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                    onPressed: () => _showReturnCustodyDialog(context, _selectedTechnicianId!, product, quantity),
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
      ],
    );
  }

  void _showIssueCustodyDialog(BuildContext context, int technicianId) async {
    final db = ref.read(databaseProvider);
    final products = await db.select(db.products).get();
    
    if (context.mounted) {
      int? selectedProductId;
      final qtyCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('صرف عهدة للفني'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedProductId,
                  items: products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (بالمخزن: ${p.currentStock})'))).toList(),
                  onChanged: (v) => setState(() => selectedProductId = v),
                  decoration: const InputDecoration(labelText: 'اختر المنتج'),
                ),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (selectedProductId == null || qty <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار منتج وكمية صحيحة'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  final product = await (db.select(db.products)..where((t) => t.id.equals(selectedProductId!))).getSingle();
                  if (product.currentStock < qty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الكمية في المخزن لا تكفي')));
                    return;
                  }
                  
                  await db.transaction(() async {
                    // 1. Deduct from Main Stock
                    await (db.update(db.products)..where((t) => t.id.equals(product.id)))
                        .write(ProductsCompanion(currentStock: drift.Value(product.currentStock - qty)));
                        
                    // 2. Add movement record
                    await db.into(db.inventoryMovements).insert(
                      InventoryMovementsCompanion.insert(
                        productId: product.id,
                        type: 'OUT_CUSTODY',
                        quantity: qty,
                        notes: drift.Value('صرف عهدة للفني رقم $technicianId'),
                      )
                    );
                    
                    // 3. Add to Custody
                    final existing = await (db.select(db.technicianCustody)
                          ..where((t) => t.technicianId.equals(technicianId) & t.productId.equals(product.id)))
                        .getSingleOrNull();
                        
                    if (existing != null) {
                      await (db.update(db.technicianCustody)..where((t) => t.id.equals(existing.id)))
                          .write(TechnicianCustodyCompanion(quantity: drift.Value(existing.quantity + qty)));
                    } else {
                      await db.into(db.technicianCustody).insert(
                        TechnicianCustodyCompanion.insert(
                          technicianId: technicianId,
                          productId: product.id,
                          quantity: drift.Value(qty),
                        )
                      );
                    }
                  });

                  if (ctx.mounted) {
                    ref.invalidate(custodyProvider);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('صرف'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showReturnCustodyDialog(BuildContext context, int technicianId, Product product, int maxQty) {
    final qtyCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استرجاع للمخزن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المنتج: ${product.name}'),
            Text('الكمية في العهدة: $maxQty'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(labelText: 'الكمية المسترجعة'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              if (qty > 0 && qty <= maxQty) {
                final db = ref.read(databaseProvider);
                
                await db.transaction(() async {
                  // 1. Add to Main Stock
                  final currentProduct = await (db.select(db.products)..where((t) => t.id.equals(product.id))).getSingle();
                  await (db.update(db.products)..where((t) => t.id.equals(product.id)))
                      .write(ProductsCompanion(currentStock: drift.Value(currentProduct.currentStock + qty)));
                      
                  // 2. Add movement record
                  await db.into(db.inventoryMovements).insert(
                    InventoryMovementsCompanion.insert(
                      productId: product.id,
                      type: 'IN_CUSTODY_RETURN',
                      quantity: qty,
                      notes: drift.Value('استرجاع من عهدة الفني رقم $technicianId للمخزن'),
                    )
                  );
                  
                  // 3. Deduct from Custody
                  final existing = await (db.select(db.technicianCustody)
                        ..where((t) => t.technicianId.equals(technicianId) & t.productId.equals(product.id)))
                      .getSingleOrNull();
                      
                  if (existing != null) {
                    if (existing.quantity - qty <= 0) {
                      await (db.delete(db.technicianCustody)..where((t) => t.id.equals(existing.id))).go();
                    } else {
                      await (db.update(db.technicianCustody)..where((t) => t.id.equals(existing.id)))
                          .write(TechnicianCustodyCompanion(quantity: drift.Value(existing.quantity - qty)));
                    }
                  }
                });

                if (ctx.mounted) {
                  ref.invalidate(custodyProvider);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم استرجاع الكمية للمخزن بنجاح'), backgroundColor: Colors.green));
                  Navigator.pop(ctx);
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('كمية غير صالحة')));
              }
            },
            child: const Text('استرجاع'),
          ),
        ],
      ),
    );
  }
}
