import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';

import 'sales_providers.dart';

final invoiceSearchProvider = FutureProvider.family<SalesInvoice?, String>((ref, query) async {
  final db = ref.watch(databaseProvider);
  final intQuery = int.tryParse(query);
  final q = db.select(db.salesInvoices)..where((t) {
    if (intQuery != null) {
      return t.id.equals(intQuery) | t.invoiceNumber.contains(query);
    }
    return t.invoiceNumber.contains(query);
  });
  final results = await q.get();
  return results.isNotEmpty ? results.first : null;
});

final invoiceItemsProvider = FutureProvider.family<List<InvoiceItem>, int>((ref, invoiceId) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
});

class SalesReturnsScreen extends ConsumerStatefulWidget {
  const SalesReturnsScreen({super.key});

  @override
  ConsumerState<SalesReturnsScreen> createState() => _SalesReturnsScreenState();
}

class _SalesReturnsScreenState extends ConsumerState<SalesReturnsScreen> {
  final _searchCtrl = TextEditingController();
  String? _searchQueryValue;
  final Map<int, int> _returnQuantities = {};
  String _historySearchQuery = '';
  
  void _search() {
    final query = _searchCtrl.text.trim();
    if (query.isNotEmpty) {
      setState(() {
        _searchQueryValue = query;
        _returnQuantities.clear();
      });
    }
  }

  Future<void> _processReturn(BuildContext context, SalesInvoice invoice, List<InvoiceItem> items) async {
    int totalItemsToReturn = 0;
    double totalReturnAmount = 0;

    for (final item in items) {
      final retQ = _returnQuantities[item.id] ?? 0;
      if (retQ > 0) {
        totalItemsToReturn += retQ;
        totalReturnAmount += (retQ * item.unitPrice);
      }
    }

    if (totalItemsToReturn == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم تحديد أي كميات للإرجاع')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإرجاع'),
        content: Text('هل أنت متأكد من إرجاع $totalItemsToReturn منتج بقيمة $totalReturnAmount ج.م؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseProvider);
    
    try {
      await db.transaction(() async {
        // 1. Create Return Record
        final returnId = await db.into(db.salesReturns).insert(
          SalesReturnsCompanion.insert(
            invoiceId: invoice.id,
            totalAmount: totalReturnAmount,
            notes: const drift.Value('إرجاع من شاشة المرتجعات'),
          ),
        );

        // 2. Process each returned item
        for (final item in items) {
          final retQ = _returnQuantities[item.id] ?? 0;
          if (retQ > 0) {
            await db.into(db.salesReturnItems).insert(
              SalesReturnItemsCompanion.insert(
                returnId: returnId,
                productId: item.productId,
                quantity: retQ,
                unitPrice: item.unitPrice,
              ),
            );

            // 3. Add to Inventory Movement
            await db.into(db.inventoryMovements).insert(
              InventoryMovementsCompanion.insert(
                productId: item.productId,
                type: 'IN_RETURN',
                quantity: retQ,
                referenceId: drift.Value(returnId.toString()),
                notes: const drift.Value('مرتجع مبيعات'),
              ),
            );

            // 4. Update Product Stock
            final product = await (db.select(db.products)..where((t) => t.id.equals(item.productId))).getSingle();
            await (db.update(db.products)..where((t) => t.id.equals(item.productId))).write(
              ProductsCompanion(currentStock: drift.Value(product.currentStock + retQ)),
            );
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تسجيل المرتجع وتحديث المخزون بنجاح'), backgroundColor: Colors.green));
        setState(() {
          _searchQueryValue = null;
          _searchCtrl.clear();
          _returnQuantities.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppLayout(
        title: 'مرتجعات المبيعات',
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'إنشاء مرتجع'),
                Tab(text: 'سجل المرتجعات'),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCreateReturnTab(),
                  _buildReturnsHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateReturnTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم فاتورة المبيعات',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.receipt),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('بحث'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_searchQueryValue != null) ...[
            ref.watch(invoiceSearchProvider(_searchQueryValue!)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('خطأ: $e'),
              data: (invoice) {
                if (invoice == null) {
                  return const Center(child: Text('❌ لا توجد فاتورة بهذا الرقم', style: TextStyle(color: Colors.red, fontSize: 18)));
                }
                return Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تفاصيل الفاتورة #${invoice.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('التاريخ: ${invoice.date.toString().split('.')[0]}'),
                          Text('الإجمالي: ${invoice.totalAmount} ج.م'),
                          const Divider(),
                          const Text('حدد الكميات المراد إرجاعها:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ref.watch(invoiceItemsProvider(invoice.id)).when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (e, st) => Text('خطأ: $e'),
                              data: (items) {
                                return ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    final currentRetQ = _returnQuantities[item.id] ?? 0;
                                    return ListTile(
                                      title: Text('منتج رقم: ${item.productId}'),
                                      subtitle: Text('السعر: ${item.unitPrice} | الكمية المباعة: ${item.quantity}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                                            onPressed: currentRetQ > 0 ? () => setState(() => _returnQuantities[item.id] = currentRetQ - 1) : null,
                                          ),
                                          Text(currentRetQ.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle, color: Colors.green),
                                            onPressed: currentRetQ < item.quantity ? () => setState(() => _returnQuantities[item.id] = currentRetQ + 1) : null,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => ref.read(invoiceItemsProvider(invoice.id)).whenData((items) => _processReturn(context, invoice, items)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(16)),
                              child: const Text('تنفيذ الإرجاع', style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          ]
        ],
      ),
    );
  }

  Widget _buildReturnsHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث برقم المرتجع أو رقم الفاتورة...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) => setState(() => _historySearchQuery = v.trim().toLowerCase()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ref.watch(salesReturnsStreamProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('خطأ: $e')),
                data: (returns) {
                  final filtered = _historySearchQuery.isEmpty ? returns : returns.where((r) {
                    return r.id.toString().contains(_historySearchQuery) ||
                           r.invoiceId.toString().contains(_historySearchQuery) ||
                           (r.notes?.toLowerCase().contains(_historySearchQuery) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('لا توجد مرتجعات مطابقة للبحث'));
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('رقم المرتجع')),
                          DataColumn(label: Text('تاريخ المرتجع')),
                          DataColumn(label: Text('رقم الفاتورة الأصلية')),
                          DataColumn(label: Text('إجمالي المبلغ المُرجع')),
                          DataColumn(label: Text('ملاحظات')),
                        ],
                        rows: filtered.map((r) => DataRow(
                          cells: [
                            DataCell(Text(r.id.toString())),
                            DataCell(Text(r.returnDate.toString().substring(0, 16))),
                            DataCell(Text(r.invoiceId.toString())),
                            DataCell(Text('${r.totalAmount} ج.م', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            DataCell(Text(r.notes ?? '')),
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
    );
  }
}
