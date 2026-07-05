import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/customers/presentation/add_customer_screen.dart';
import '../../features/customers/presentation/legacy_customer_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/products/presentation/add_product_screen.dart';
import '../../core/database/app_database.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/sales/presentation/create_invoice_screen.dart';
import '../../features/sales/presentation/installment_wizard_screen.dart';
import '../../features/sales/presentation/sales_returns_screen.dart';
import '../../features/collections/presentation/collections_screen.dart';
import '../../features/collections/presentation/installments_full_screen.dart';
import '../../features/maintenance/presentation/maintenance_screen.dart';
import '../../features/maintenance/presentation/internal_maintenance_screen.dart';
import '../../features/maintenance/presentation/maintenance_schedules_screen.dart';
import '../../features/maintenance/presentation/maintenance_calendar_screen.dart';
import '../../features/maintenance/presentation/maintenance_returns_screen.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/reports/presentation/commissions_report_screen.dart';
import '../../features/reports/presentation/technician_log_screen.dart';
import '../../features/reports/presentation/profit_loss_report_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/company_profile_screen.dart';
import '../../features/settings/presentation/monthly_archives_screen.dart';
import '../../features/purchases/presentation/purchases_screen.dart';
import '../../features/inventory/presentation/inventory_audit_screen.dart';
import '../../features/inventory/presentation/item_ledger_screen.dart';
import '../../features/hr/presentation/hr_dashboard_screen.dart';
import '../../features/hr/presentation/payroll_processing_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../../features/products/presentation/used_products_screen.dart';
import '../../features/products/presentation/product_price_list_screen.dart';
import '../../features/inventory/presentation/custody_management_screen.dart';
import '../../features/settings/presentation/backup_screen.dart';
import '../../features/cash_drawer/presentation/cash_drawer_screen.dart';
import '../../features/maintenance/presentation/due_maintenance_screen.dart';
import '../../features/products/presentation/barcode_label_screen.dart';
import '../../features/offers/presentation/offers_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/dashboard';
      if (isLoggedIn && state.matchedLocation == '/') return '/dashboard';

      // Role-Based Access Control logic
      if (isLoggedIn) {
        final role = currentUser.role;
        final loc = state.matchedLocation;

        // Admin and Manager have access to everything
        if (role == 'Administrator' || role == 'Manager') return null;

        // Restrict /hr, /settings, /users, /reports, /expenses to Admin/Manager only
        if (loc.startsWith('/hr') ||
            loc.startsWith('/settings') ||
            loc.startsWith('/users') ||
            loc.startsWith('/reports') ||
            loc.startsWith('/expenses')) {
          return '/dashboard'; // Redirect unauthorized access to dashboard
        }

        // Warehouse can access products, purchases, inventory
        if (role == 'Warehouse') {
          final allowed =
              loc.startsWith('/dashboard') ||
              loc.startsWith('/products') ||
              loc.startsWith('/purchases') ||
              loc.startsWith('/inventory') ||
              loc.startsWith('/item-ledger') ||
              loc.startsWith('/technician-custody') ||
              loc.startsWith('/maintenance-returns');
          if (!allowed) return '/dashboard';
        }

        // Sales can access customers, products, sales, collections, schedules, and offers
        if (role == 'Sales') {
          final restricted =
              loc.startsWith('/internal-maintenance') ||
              loc.startsWith('/cash-drawer');
          if (restricted) return '/dashboard';
        }

        // Technician can access maintenance, products
        if (role == 'Technician') {
          final allowed =
              loc.startsWith('/dashboard') ||
              loc.startsWith('/maintenance') ||
              loc.startsWith('/internal-maintenance') ||
              loc.startsWith('/due-maintenance') ||
              loc.startsWith('/maintenance-calendar') ||
              loc.startsWith('/maintenance-schedules');
          if (!allowed) return '/dashboard';
        }

        // Collector can access collections
        if (role == 'Collector') {
          final allowed =
              loc.startsWith('/dashboard') ||
              loc.startsWith('/collections') ||
              loc.startsWith('/installments');
          if (!allowed) return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/customers',
        name: 'customers',
        builder: (context, state) => const CustomersScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'add_customer',
            builder: (context, state) {
              final customer = state.extra as Customer?;
              return AddCustomerScreen(customerToEdit: customer);
            },
          ),
          GoRoute(
            path: 'legacy',
            name: 'legacy_customer',
            builder: (context, state) => const LegacyCustomerScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/products',
        name: 'products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/products/add',
        name: 'add_product',
        builder: (context, state) {
          final product = state.extra as Product?;
          return AddProductScreen(productToEdit: product);
        },
      ),
      GoRoute(
        path: '/products/add-used',
        name: 'add_used_product',
        builder: (context, state) => const AddProductScreen(productType: 1),
      ),
      GoRoute(
        path: '/sales',
        name: 'sales',
        builder: (context, state) => const SalesScreen(),
      ),
      GoRoute(
        path: '/create-invoice',
        name: 'create_invoice',
        builder: (context, state) => const CreateInvoiceScreen(),
      ),

      GoRoute(
        path: '/sales-returns',
        name: 'sales_returns',
        builder: (context, state) => const SalesReturnsScreen(),
      ),
      GoRoute(
        path: '/collections',
        name: 'collections',
        builder: (context, state) => const CollectionsScreen(),
      ),
      GoRoute(
        path: '/installments',
        name: 'installments',
        builder: (context, state) => const InstallmentsFullScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        name: 'maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/internal-maintenance',
        name: 'internal_maintenance',
        builder: (context, state) => const InternalMaintenanceScreen(),
      ),
      GoRoute(
        path: '/maintenance-schedules',
        name: 'maintenance_schedules',
        builder: (context, state) => const MaintenanceSchedulesScreen(),
      ),
      GoRoute(
        path: '/maintenance-calendar',
        name: 'maintenance_calendar',
        builder: (context, state) => const MaintenanceCalendarScreen(),
      ),
      GoRoute(
        path: '/maintenance-returns',
        name: 'maintenance_returns',
        builder: (context, state) => const MaintenanceReturnsScreen(),
      ),
      GoRoute(
        path: '/expenses',
        name:
            'expenses', // Wait, the side bar maps to /expenses? Let me check sidebar: no, sidebar has reports and settings but I'll add expenses route anyway
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/hr',
        name: 'hr_dashboard',
        builder: (context, state) => const HRDashboardScreen(),
      ),
      GoRoute(
        path: '/hr/payroll-processing',
        name: 'payroll_processing',
        builder: (context, state) => const PayrollProcessingScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'company',
            builder: (context, state) => const CompanyProfileScreen(),
          ),
          GoRoute(
            path: 'archives',
            builder: (context, state) => const MonthlyArchivesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/purchases',
        name: 'purchases',
        builder: (context, state) => const PurchasesScreen(),
      ),
      GoRoute(
        path: '/users',
        name: 'users',
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: '/used-products',
        name: 'used_products',
        builder: (context, state) => const UsedProductsScreen(),
      ),
      GoRoute(
        path: '/price-list',
        name: 'price_list',
        builder: (context, state) => const ProductPriceListScreen(),
      ),
      GoRoute(
        path: '/inventory-audit',
        name: 'inventory_audit',
        builder: (context, state) => const InventoryAuditScreen(),
      ),
      GoRoute(
        path: '/item-ledger',
        name: 'item_ledger',
        builder: (context, state) => const ItemLedgerScreen(),
      ),
      GoRoute(
        path: '/technician-custody',
        name: 'technician_custody',
        builder: (context, state) => const CustodyManagementScreen(),
      ),
      GoRoute(
        path: '/commissions-report',
        name: 'commissions_report',
        builder: (context, state) => const CommissionsReportScreen(),
      ),
      GoRoute(
        path: '/technician-log',
        name: 'technician_log',
        builder: (context, state) => const TechnicianLogScreen(),
      ),
      GoRoute(
        path: '/profit-loss',
        name: 'profit_loss',
        builder: (context, state) => const ProfitLossReportScreen(),
      ),
      GoRoute(
        path: '/backup',
        name: 'backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/cash-drawer',
        name: 'cash_drawer',
        builder: (context, state) => const CashDrawerScreen(),
      ),
      GoRoute(
        path: '/due-maintenance',
        name: 'due_maintenance',
        builder: (context, state) => const DueMaintenanceScreen(),
      ),
      GoRoute(
        path: '/barcode-labels',
        name: 'barcode_labels',
        builder: (context, state) => const BarcodeLabelScreen(),
      ),
      GoRoute(
        path: '/offers',
        name: 'offers',
        builder: (context, state) => const OffersScreen(),
      ),
      // TODO: Add more routes here for auth, customers, products, etc.
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('خطأ في الصفحة: ${state.error}'))),
  );
});
