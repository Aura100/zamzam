import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../core/database/database_provider.dart';

class _AlertItem {
  final String message;
  final IconData icon;
  final Color color;
  _AlertItem(this.message, this.icon, this.color);
}

final alertsProvider = FutureProvider<List<_AlertItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final alerts = <_AlertItem>[];

  // Low stock
  final products = await (db.select(
    db.products,
  )..where((t) => t.isDeleted.equals(false))).get();
  final lowStock = products.where((p) => p.currentStock <= p.minStock).toList();
  if (lowStock.isNotEmpty) {
    alerts.add(
      _AlertItem(
        '${lowStock.length} منتج أقل من الحد الأدنى للمخزون',
        Icons.warning,
        Colors.orange,
      ),
    );
  }

  // Overdue installments
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final overdue =
      await (db.select(db.installments)..where(
            (t) =>
                t.dueDate.isSmallerThanValue(todayStart) &
                t.status.equals('Pending'),
          ))
          .get();
  if (overdue.isNotEmpty) {
    alerts.add(
      _AlertItem(
        '${overdue.length} قسط متأخر عن السداد',
        Icons.payment,
        Colors.red,
      ),
    );
  }

  // Pending maintenance
  final pendingMaint = await (db.select(
    db.maintenanceRequests,
  )..where((t) => t.status.equals('Pending'))).get();
  if (pendingMaint.isNotEmpty) {
    alerts.add(
      _AlertItem(
        '${pendingMaint.length} طلب صيانة معلق',
        Icons.build_circle,
        Colors.blue,
      ),
    );
  }

  // Upcoming/overdue maintenance schedules (next 7 days)
  final dueSchedules =
      await (db.select(db.maintenanceSchedules)..where(
            (t) =>
                t.status.equals('Active') &
                t.nextMaintenanceDate.isSmallerOrEqualValue(
                  now.add(const Duration(days: 7)),
                ),
          ))
          .get();
  if (dueSchedules.isNotEmpty) {
    final overdueSchedules = dueSchedules
        .where((s) => s.nextMaintenanceDate.isBefore(now))
        .length;
    if (overdueSchedules > 0) {
      alerts.add(
        _AlertItem(
          '$overdueSchedules صيانة دورية متأخرة!',
          Icons.event_busy,
          Colors.red,
        ),
      );
    } else {
      alerts.add(
        _AlertItem(
          '${dueSchedules.length} صيانة دورية مستحقة هذا الأسبوع',
          Icons.event_available,
          Colors.orange,
        ),
      );
    }
  }

  return alerts;
});

class AppLayout extends ConsumerWidget {
  final Widget child;
  final String title;
  final Widget? floatingActionButton;

  const AppLayout({
    super.key,
    required this.child,
    required this.title,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final currentUser = ref.watch(currentUserProvider);

    final List<_NavigationItem> allNavItems = [
      _NavigationItem(
        'لوحة التحكم',
        Icons.dashboard,
        '/dashboard',
        allowedRoles: ['Administrator', 'Manager'],
      ),
      _NavigationItem(
        'العملاء',
        Icons.people,
        '/customers',
        allowedRoles: ['Administrator', 'Manager', 'Sales'],
      ),
      _NavigationItem(
        'شؤون الموظفين',
        Icons.badge,
        '/hr',
        allowedRoles: ['Administrator', 'Manager'],
      ),
      _NavigationItem(
        'سجل الفنيين',
        Icons.engineering,
        '/technician-log',
        allowedRoles: ['Administrator', 'Manager', 'HR'],
      ),
      _NavigationItem(
        'المنتجات',
        Icons.inventory_2,
        '/products',
        allowedRoles: ['Administrator', 'Manager', 'Sales', 'Warehouse'],
      ),
      _NavigationItem(
        'المنتجات المستعملة',
        Icons.recycling,
        '/used-products',
        allowedRoles: ['Administrator', 'Manager', 'Warehouse', 'Sales'],
      ),
      _NavigationItem(
        'حركة الصنف',
        Icons.manage_history,
        '/item-ledger',
        allowedRoles: ['Administrator', 'Manager', 'Warehouse'],
      ),
      _NavigationItem(
        'كشف الأسعار (PDF)',
        Icons.price_change,
        '/price-list',
        allowedRoles: ['Administrator', 'Manager', 'Sales'],
      ),
      _NavigationItem(
        'الجرد الشهري',
        Icons.playlist_add_check,
        '/inventory-audit',
        allowedRoles: ['Administrator', 'Manager', 'Warehouse'],
      ),
      _NavigationItem(
        'عُهد الفنيين',
        Icons.assignment,
        '/technician-custody',
        allowedRoles: ['Administrator', 'Manager', 'Warehouse'],
      ),
      _NavigationItem(
        'إدارة الخزينة',
        Icons.account_balance_wallet,
        '/cash-drawer',
        allowedRoles: ['Administrator', 'Manager'],
      ),
      _NavigationItem(
        'المبيعات',
        Icons.point_of_sale,
        '/sales',
        allowedRoles: ['Administrator', 'Manager', 'Sales'],
      ),
      _NavigationItem(
        'العروض والتخفيفات',
        Icons.local_offer,
        '/offers',
        allowedRoles: ['Administrator', 'Manager', 'Sales'],
      ),
      _NavigationItem(
        'مرتجعات المبيعات',
        Icons.remove_shopping_cart,
        '/sales-returns',
        allowedRoles: ['Administrator', 'Manager', 'Sales', 'Warehouse'],
      ),
      _NavigationItem(
        'التحصيلات',
        Icons.attach_money,
        '/collections',
        allowedRoles: ['Administrator', 'Manager', 'Sales', 'Collector'],
      ),
      _NavigationItem(
        'جدول الأقساط 📋',
        Icons.table_chart,
        '/installments',
        allowedRoles: ['Administrator', 'Manager', 'Sales', 'Collector'],
      ),
      _NavigationItem(
        'الصيانة الخارجية',
        Icons.build,
        '/maintenance',
        allowedRoles: ['Administrator', 'Manager', 'Technician'],
      ),
      _NavigationItem(
        'الصيانة الداخلية',
        Icons.business_center,
        '/internal-maintenance',
        allowedRoles: ['Administrator', 'Manager', 'Technician'],
      ),
      _NavigationItem(
        'صيانات مستحقة 🔔',
        Icons.event_busy,
        '/due-maintenance',
        allowedRoles: ['Administrator', 'Manager', 'Sales', 'Technician'],
      ),
      _NavigationItem(
        'جدولة الصيانة',
        Icons.calendar_month,
        '/maintenance-schedules',
        allowedRoles: ['Administrator', 'Manager', 'Sales', 'Technician'],
      ),
      _NavigationItem(
        'كشف المواعيد',
        Icons.schedule,
        '/maintenance-calendar',
        allowedRoles: ['Administrator', 'Manager', 'Sales', 'Technician'],
      ),
      _NavigationItem(
        'مرتجعات الصيانة',
        Icons.assignment_return,
        '/maintenance-returns',
        allowedRoles: ['Administrator', 'Manager', 'Warehouse', 'Technician'],
      ),
      _NavigationItem(
        'المصروفات',
        Icons.money_off,
        '/expenses',
        allowedRoles: ['Administrator', 'Manager'],
      ),
      _NavigationItem(
        'المشتريات',
        Icons.shopping_cart,
        '/purchases',
        allowedRoles: ['Administrator', 'Manager', 'Warehouse'],
      ),
      _NavigationItem(
        'التقارير',
        Icons.bar_chart,
        '/reports',
        allowedRoles: ['Administrator', 'Manager'],
      ),
      _NavigationItem(
        'عمولات الفنيين',
        Icons.engineering,
        '/commissions-report',
        allowedRoles: ['Administrator', 'Manager'],
      ),
      _NavigationItem(
        'طباعة ملصقات الباركود',
        Icons.qr_code_2,
        '/barcode-labels',
        allowedRoles: ['Administrator', 'Manager', 'Warehouse', 'Sales'],
      ),
      _NavigationItem(
        'المستخدمين والفنيين',
        Icons.manage_accounts,
        '/users',
        allowedRoles: ['Administrator'],
      ),
      _NavigationItem(
        'النسخ الاحتياطي',
        Icons.backup,
        '/backup',
        allowedRoles: ['Administrator'],
      ),
      _NavigationItem(
        'الإعدادات',
        Icons.settings,
        '/settings',
        allowedRoles: ['Administrator'],
      ),
    ];

    final userRole = currentUser?.role ?? '';
    final navItems = allNavItems
        .where((item) => item.allowedRoles.contains(userRole))
        .toList();

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 250,
              color: Theme.of(context).primaryColor,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.water_drop, size: 64, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'زمزم للفلاتر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: navItems.length,
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        return ListTile(
                          leading: Icon(item.icon, color: Colors.white70),
                          title: Text(
                            item.label,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () => context.go(item.route),
                        );
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.white),
                    title: const Text(
                      'تسجيل خروج',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      ref.read(authNotifierProvider.notifier).logout();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(title),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 1,
                  actions: [
                    // Notifications bell
                    ref
                        .watch(alertsProvider)
                        .when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (alerts) {
                            return PopupMenuButton<_AlertItem>(
                              icon: Badge(
                                isLabelVisible: alerts.isNotEmpty,
                                label: Text('${alerts.length}'),
                                child: Icon(
                                  Icons.notifications,
                                  color: alerts.isNotEmpty
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                              ),
                              itemBuilder: (ctx) {
                                if (alerts.isEmpty) {
                                  return [
                                    const PopupMenuItem(
                                      enabled: false,
                                      child: Text('لا توجد تنبيهات'),
                                    ),
                                  ];
                                }
                                return alerts
                                    .map(
                                      (a) => PopupMenuItem(
                                        value: a,
                                        child: Row(
                                          children: [
                                            Icon(
                                              a.icon,
                                              color: a.color,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(a.message)),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList();
                              },
                            );
                          },
                        ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'المستخدم: ${currentUser?.name ?? ""}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                body: child,
                floatingActionButton: floatingActionButton,
                backgroundColor: Theme.of(context).colorScheme.background,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              accountName: Text(currentUser?.name ?? 'مستخدم'),
              accountEmail: Text(currentUser?.role ?? 'موظف'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  return ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      context.go(item.route);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _NavigationItem {
  final String label;
  final IconData icon;
  final String route;
  final List<String> allowedRoles;

  _NavigationItem(
    this.label,
    this.icon,
    this.route, {
    this.allowedRoles = const ['Administrator', 'Manager'],
  });
}
