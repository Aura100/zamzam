import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../products/presentation/products_providers.dart';

final inventoryMovementsProvider = FutureProvider.family<List<InventoryMovement>, int>((ref, productId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.inventoryMovements)
        ..where((t) => t.productId.equals(productId))
        ..orderBy([(t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc)]))
      .get();
});

class ItemLedgerScreen extends ConsumerStatefulWidget {
  const ItemLedgerScreen({super.key});

  @override
  ConsumerState<ItemLedgerScreen> createState() => _ItemLedgerScreenState();
}

class _ItemLedgerScreenState extends ConsumerState<ItemLedgerScreen> {
  int? _selectedProductId;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return AppLayout(
      title: 'حركة الصنف (Item Ledger)',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Text('اختر المنتج:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Expanded(
                  child: productsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, st) => Text('خطأ: $e'),
                    data: (products) {
                      return DropdownButtonFormField<int>(
                        value: _selectedProductId,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: products.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (رقم: ${p.id})'),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProductId = val;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedProductId != null) ...[
              Expanded(
                child: ref.watch(inventoryMovementsProvider(_selectedProductId!)).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('خطأ: $e')),
                  data: (movements) {
                    if (movements.isEmpty) {
                      return const Center(child: Text('لا توجد حركات مسجلة لهذا المنتج.'));
                    }
                    return Card(
                      child: ListView.separated(
                        itemCount: movements.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final mov = movements[index];
                          final isOut = mov.type == 'OUT_SALE' || mov.type == 'OUT_MAINTENANCE' || mov.type == 'OUT_LOSS';
                          final isIn = mov.type == 'IN_PURCHASE' || mov.type == 'IN_RETURN' || mov.type == 'IN_ADJUSTMENT';
                          
                          Color iconColor = Colors.grey;
                          IconData icon = Icons.swap_horiz;
                          
                          if (isIn) {
                            iconColor = Colors.green;
                            icon = Icons.arrow_downward;
                          } else if (isOut) {
                            iconColor = Colors.red;
                            icon = Icons.arrow_upward;
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: iconColor.withOpacity(0.2),
                              child: Icon(icon, color: iconColor),
                            ),
                            title: Text('الكمية: ${mov.quantity}'),
                            subtitle: Text('النوع: ${mov.type} | الملاحظات: ${mov.notes ?? ""}'),
                            trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(mov.date)),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text('يرجى اختيار منتج لعرض حركته', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
