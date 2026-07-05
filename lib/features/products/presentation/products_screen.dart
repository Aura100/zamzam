import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/excel_export_service.dart';
import 'products_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppLayout(
        title: 'إدارة المنتجات',
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(
                    width: 250,
                    child: TabBar(
                      tabs: [
                        Tab(text: 'جديدة'),
                        Tab(text: 'مستعملة'),
                      ],
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 250,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'ابحث عن منتج...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _exportProducts(context, ref),
                        icon: const Icon(Icons.download),
                        label: const Text('تصدير إكسيل'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/products/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة منتج جديد'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Products List
              Expanded(
                child: TabBarView(
                  children: [
                    _buildProductsTab(context, ref, ref.watch(newProductsStreamProvider)),
                    _buildProductsTab(context, ref, ref.watch(usedProductsStreamProvider)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context, WidgetRef ref, AsyncValue<List<dynamic>> asyncProducts) {
    return Card(
      child: asyncProducts.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                  data: (products) {
                    final filtered = _searchQuery.isEmpty ? products : products.where((p) {
                      final nameMatch = p.name.toLowerCase().contains(_searchQuery);
                      final arabicNameMatch = p.arabicName?.toLowerCase().contains(_searchQuery) ?? false;
                      final catMatch = p.category.toLowerCase().contains(_searchQuery);
                      final skuMatch = p.sku?.toLowerCase().contains(_searchQuery) ?? false;
                      return nameMatch || arabicNameMatch || catMatch || skuMatch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(child: Text(_searchQuery.isEmpty ? 'لا يوجد منتجات. أضف منتج جديد.' : 'لا توجد نتائج مطابقة للبحث'));
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('الكود (SKU)')),
                            DataColumn(label: Text('الاسم')),
                            DataColumn(label: Text('الفئة')),
                            DataColumn(label: Text('سعر الكاش')),
                            DataColumn(label: Text('سعر القسط')),
                            DataColumn(label: Text('المخزون')),
                            DataColumn(label: Text('إجراءات')),
                          ],
                          rows: filtered.map((p) => DataRow(
                            cells: [
                              DataCell(Text(p.sku ?? p.id.toString())),
                              DataCell(Text(p.name)),
                              DataCell(Text(p.category)),
                              DataCell(Text('${p.cashPrice} ج.م')),
                              DataCell(Text('${p.installmentPrice} ج.م')),
                              DataCell(
                                Text(
                                  p.currentStock.toString(),
                                  style: TextStyle(
                                    color: p.currentStock <= p.minStock ? Colors.red : Colors.black,
                                    fontWeight: p.currentStock <= p.minStock ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        context.push('/products/add', extra: p);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('تأكيد الحذف'),
                                              content: const Text('هل أنت متأكد من حذف هذا المنتج؟'),
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
                                            await ref.read(productsRepositoryProvider).deleteProduct(p.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('تم حذف المنتج بنجاح')),
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
    );
  }

  Future<void> _exportProducts(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final products = await db.select(db.products).get();
    final headers = ['ID', 'SKU', 'الاسم', 'الفئة', 'سعر الشراء', 'سعر الكاش', 'سعر القسط', 'المخزون الحالي', 'الحد الأدنى للمخزون'];
    final rows = products.map((p) => [
      p.id,
      p.sku ?? '',
      p.name,
      p.category,
      p.purchasePrice ?? 0.0,
      p.cashPrice,
      p.installmentPrice,
      p.currentStock,
      p.minStock,
    ]).toList();

    final success = await ExcelExportService.exportToExcel(
      filename: 'جدول_المنتجات_${DateTime.now().day}_${DateTime.now().month}',
      headers: headers,
      rows: rows,
    );

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تصدير ملف المنتجات بنجاح'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ فشل تصدير الملف'), backgroundColor: Colors.red));
      }
    }
  }
}
