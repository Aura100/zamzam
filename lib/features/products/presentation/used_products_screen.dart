import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';

final usedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.products)
    ..where((t) => t.isDeleted.equals(false) & t.productType.equals(1));
  return query.get();
});

class UsedProductsScreen extends ConsumerStatefulWidget {
  const UsedProductsScreen({super.key});

  @override
  ConsumerState<UsedProductsScreen> createState() => _UsedProductsScreenState();
}

class _UsedProductsScreenState extends ConsumerState<UsedProductsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'الكل';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(usedProductsProvider);

    return AppLayout(
      title: 'المنتجات المستعملة',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/products/add-used'),
        icon: const Icon(Icons.add),
        label: const Text('إضافة منتج مستعمل'),
        backgroundColor: Colors.deepOrange,
      ),
      child: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepOrange.shade700, Colors.orange.shade400],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.recycling, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المنتجات المستعملة',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'إدارة المنتجات المستعملة والمُجدَّدة',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث في المنتجات المستعملة...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Products list
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('خطأ: $err')),
              data: (products) {
                final filtered = products.where((p) {
                  final matchSearch = _searchQuery.isEmpty ||
                      p.name.toLowerCase().contains(_searchQuery) ||
                      (p.arabicName?.toLowerCase().contains(_searchQuery) ?? false) ||
                      p.category.toLowerCase().contains(_searchQuery);
                  return matchSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'لا توجد منتجات مستعملة مسجّلة'
                              : 'لا توجد نتائج مطابقة',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/products/add-used'),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة منتج مستعمل'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _UsedProductCard(
                      product: p,
                      onEdit: () => _editProduct(p),
                      onDelete: () => _deleteProduct(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProduct(Product p) async {
    context.go('/products/add', extra: p);
  }

  Future<void> _deleteProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "${p.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await (db.update(db.products)..where((t) => t.id.equals(p.id)))
          .write(ProductsCompanion(isDeleted: const drift.Value(true)));
      ref.invalidate(usedProductsProvider);
    }
  }
}

class _UsedProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UsedProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final stockColor = product.currentStock == 0
        ? Colors.red
        : product.currentStock <= product.minStock
            ? Colors.orange
            : Colors.green;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.recycling, color: Colors.deepOrange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (product.arabicName != null)
                        Text(product.arabicName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      Text(
                        product.category,
                        style: TextStyle(color: Colors.deepOrange.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'مستعمل',
                    style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _priceChip('سعر النقد', product.cashPrice, Colors.blue),
                _priceChip('سعر التقسيط', product.installmentPrice, Colors.purple),
                _priceChip('الجملة', product.wholesalePrice, Colors.teal),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: stockColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory, size: 14, color: stockColor),
                      const SizedBox(width: 4),
                      Text(
                        'المخزون: ${product.currentStock}',
                        style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: onEdit,
                      tooltip: 'تعديل',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: onDelete,
                      tooltip: 'حذف',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceChip(String label, double price, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(
          '${price.toStringAsFixed(0)} ج.م',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
