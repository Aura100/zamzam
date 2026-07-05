import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_layout.dart';
import 'dashboard_providers.dart';
import 'widgets/sales_chart.dart';
import 'widgets/collections_pie_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return AppLayout(
      title: 'لوحة التحكم',
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade400],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مرحباً بك في نظام زمزم للفلاتر',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Grid
              statsAsync.when(
                loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                error: (err, _) => Center(child: Text('خطأ في تحميل البيانات: $err')),
                data: (stats) {
                  return Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int cols = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 600 ? 2 : 1));
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: cols,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.2,
                            children: [
                              _buildStatCard(
                                context,
                                'إيرادات الشهر',
                                '${stats.totalRevenueThisMonth.toStringAsFixed(0)} ج.م',
                                Icons.attach_money,
                                Colors.blue,
                                onTap: () => context.go('/sales'),
                              ),
                              _buildStatCard(
                                context,
                                'تحصيلات اليوم',
                                '${stats.totalCollectionsToday.toStringAsFixed(0)} ج.م',
                                Icons.money,
                                Colors.green,
                                onTap: () => context.go('/collections'),
                              ),
                              _buildStatCard(
                                context,
                                'أقساط متأخرة',
                                '${stats.overdueInstallments}',
                                Icons.warning,
                                stats.overdueInstallments > 0 ? Colors.red : Colors.grey,
                                onTap: () => context.go('/collections'),
                              ),
                              _buildStatCard(
                                context,
                                'إجمالي العملاء',
                                '${stats.totalCustomers}',
                                Icons.people,
                                Colors.orange,
                                onTap: () => context.go('/customers'),
                              ),
                              _buildStatCard(
                                context,
                                'فواتير اليوم',
                                '${stats.totalInvoicesToday}',
                                Icons.receipt,
                                Colors.purple,
                                onTap: () => context.go('/sales'),
                              ),
                              _buildStatCard(
                                context,
                                'إيرادات اليوم',
                                '${stats.dailyRevenue.toStringAsFixed(0)} ج.م',
                                Icons.trending_up,
                                Colors.teal,
                                onTap: () => context.go('/sales'),
                              ),
                              _buildStatCard(
                                context,
                                'منتجات نقص مخزون',
                                '${stats.lowStockProducts}',
                                Icons.inventory,
                                stats.lowStockProducts > 0 ? Colors.deepOrange : Colors.grey,
                                onTap: () => context.go('/products'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Charts Section
                      LayoutBuilder(
                        builder: (context, constraints) {
                          bool isWide = constraints.maxWidth > 800;
                          return isWide
                              ? Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Card(
                                        child: Container(
                                          height: 350,
                                          padding: const EdgeInsets.all(16),
                                          child: SalesChart(weeklySales: stats.weeklySales),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: Card(
                                        child: Container(
                                          height: 350,
                                          padding: const EdgeInsets.all(16),
                                          child: CollectionsPieChart(
                                            collected: stats.collectionsCollected,
                                            pending: stats.collectionsPending,
                                            overdue: stats.collectionsOverdue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Card(
                                      child: Container(
                                        height: 350,
                                        padding: const EdgeInsets.all(16),
                                        child: SalesChart(weeklySales: stats.weeklySales),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Card(
                                      child: Container(
                                        height: 350,
                                        padding: const EdgeInsets.all(16),
                                        child: CollectionsPieChart(
                                          collected: stats.collectionsCollected,
                                          pending: stats.collectionsPending,
                                          overdue: stats.collectionsOverdue,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions
                      Row(
                        children: [
                          Text('إجراءات سريعة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildQuickAction(context, 'فاتورة جديدة', Icons.add_shopping_cart, Colors.blue, () => context.go('/create-invoice')),
                          _buildQuickAction(context, 'عميل جديد', Icons.person_add, Colors.green, () => context.go('/customers/add')),
                          _buildQuickAction(context, 'صيانة جديدة', Icons.build_circle, Colors.orange, () => context.go('/maintenance')),
                          _buildQuickAction(context, 'تحصيل قسط', Icons.payment, Colors.purple, () => context.go('/collections')),
                          _buildQuickAction(context, 'مرتجع مبيعات', Icons.assignment_return, Colors.redAccent, () => context.go('/sales-returns')),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Low stock list
                      if (stats.lowStockProductList.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.deepOrange),
                            const SizedBox(width: 8),
                            Text('تحذير: منتجات تحتاج تجديد مخزون', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: stats.lowStockProductList.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = stats.lowStockProductList[index];
                              return ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.inventory_2, color: Colors.deepOrange),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('الفئة: ${p.category}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: p.currentStock == 0 ? Colors.red : Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    p.currentStock == 0 ? 'نفد المخزون' : 'متبقي: ${p.currentStock}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
