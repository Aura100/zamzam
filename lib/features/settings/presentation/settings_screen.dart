import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/database_archive_service.dart';
import 'package:file_selector/file_selector.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _backupDatabase(BuildContext context) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(
        p.join(dbFolder.path, 'zamzam_erp', 'zamzam_erp.sqlite'),
      );

      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('قاعدة البيانات غير موجودة')),
          );
        }
        return;
      }

      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName:
            'zamzam_backup_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.sqlite',
      );

      if (saveLocation != null) {
        await file.copy(saveLocation.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم أخذ نسخة احتياطية بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في النسخ: $e')));
      }
    }
  }

  Future<void> _restoreDatabase(BuildContext context, WidgetRef ref) async {
    try {
      // Warn user first
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('تحذير'),
            ],
          ),
          content: const Text(
            'سيتم استبدال قاعدة البيانات الحالية بالكامل ببيانات النسخة الاحتياطية.\nهذا الإجراء لا يمكن التراجع عنه.\n\nهل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('استمرار'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final XFile? file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'SQLite Database',
            extensions: ['sqlite', 'db'],
          ),
        ],
      );

      if (file == null || !context.mounted) return;

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(
        p.join(dbFolder.path, 'zamzam_erp', 'zamzam_erp.sqlite'),
      );

      // IMPORTANT: Close the database connection first.
      // Windows locks the SQLite file while in use — we must release it before delete/copy.
      final db = ref.read(databaseProvider);
      await db.close();

      // Now safe to delete and overwrite
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await File(file.path).copy(dbFile.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم استعادة قاعدة البيانات. يرجى إعادة تشغيل التطبيق.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الاستعادة: $e')));
      }
    }
  }

  Future<void> _resetDatabase(BuildContext context, WidgetRef ref) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.dangerous, color: Colors.red),
              SizedBox(width: 8),
              Text('تحذير خطير جداً', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: const Text(
            'سيتم إنشاء نسخة شهرية من قاعدة البيانات داخل مجلد الشهر، ثم سيتم تصفير البيانات التشغيلية مثل الفواتير والمبيعات والأقساط مع إبقاء المنتجات كما هي.\n\nهل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('تصفير البيانات والاحتفاظ بالمنتجات'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(
        p.join(dbFolder.path, 'zamzam_erp', 'zamzam_erp.sqlite'),
      );

      if (!await dbFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد قاعدة بيانات لحفظها')),
          );
        }
        return;
      }

      final currentDb = ref.read(databaseProvider);
      await currentDb.close();
      ref.invalidate(databaseProvider);

      final resetDb = ref.read(databaseProvider);
      final archivePath = await DatabaseArchiveService.createMonthlyArchive(
        databaseFilePath: dbFile.path,
      );

      await resetDb.transaction(() async {
        await resetDb.delete(resetDb.invoiceItems).go();
        await resetDb.delete(resetDb.salesReturnItems).go();
        await resetDb.delete(resetDb.salesReturns).go();
        await resetDb.delete(resetDb.installments).go();
        await resetDb.delete(resetDb.installmentContracts).go();
        await resetDb.delete(resetDb.maintenancePayments).go();
        await resetDb.delete(resetDb.maintenanceRequests).go();
        await resetDb.delete(resetDb.maintenanceSchedules).go();
        await resetDb.delete(resetDb.maintenanceParts).go();
        await resetDb.delete(resetDb.inventoryMovements).go();
        await resetDb.delete(resetDb.expenses).go();
        await resetDb.delete(resetDb.purchaseItems).go();
        await resetDb.delete(resetDb.purchaseInvoices).go();
        await resetDb.delete(resetDb.salesInvoices).go();
        await resetDb.delete(resetDb.offerItems).go();
        await resetDb.delete(resetDb.offers).go();
        await resetDb.delete(resetDb.cashDrawerSessions).go();
        await resetDb.delete(resetDb.payrollTransactions).go();
        await resetDb.delete(resetDb.monthlyPayrolls).go();
        await resetDb.delete(resetDb.technicianCustody).go();
        await resetDb.delete(resetDb.technicianCommissionRates).go();

        await (resetDb.update(resetDb.products)..where((t) => t.id.isNotNull()))
            .write(const ProductsCompanion(currentStock: drift.Value(0)));
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء أرشيف جديد: $archivePath'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم إنشاء أرشيف شهري وتصفير البيانات التشغيلية مع الحفاظ على المنتجات.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تصفير البيانات: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLayout(
      title: 'الإعدادات',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Section: Database
            Text(
              'قاعدة البيانات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.backup, color: Colors.blue),
                    title: const Text('نسخة احتياطية (Backup)'),
                    subtitle: const Text('حفظ قاعدة البيانات في مكان آمن'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _backupDatabase(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restore, color: Colors.orange),
                    title: const Text('استعادة نسخة احتياطية (Restore)'),
                    subtitle: const Text('تحميل قاعدة بيانات من ملف سابق'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _restoreDatabase(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'إنشاء أرشيف وتصفير البيانات',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text(
                      'سيؤدي هذا إلى إنشاء أرشيف ثم تصفير الفواتير والمبيعات والصيانات والعمولات والرواتب',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.red,
                    ),
                    onTap: () => _resetDatabase(context, ref),
                  ),
                  const Divider(height: 1),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذا الإجراء ينشئ أرشيفاً جديداً ثم يصفّر البيانات التشغيلية ويحتفظ بالمنتجات فقط. لا يمكن التراجع عنه بعد التأكيد.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.folder_open,
                      color: Colors.indigo,
                    ),
                    title: const Text('الأرشيف الشهري'),
                    subtitle: const Text(
                      'عرض كل الأشهر التي تم فيها تصفير البيانات',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/archives'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Users
            Text(
              'المستخدمون والصلاحيات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.business, color: Colors.blue),
                    title: const Text('بيانات الشركة'),
                    subtitle: const Text(
                      'الاسم، الهاتف، العنوان (تطبع على الفواتير)',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/company'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.manage_accounts,
                      color: Colors.purple,
                    ),
                    title: const Text('إدارة المستخدمين'),
                    subtitle: const Text('إضافة وتعديل وحذف مستخدمي النظام'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/users'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: About
            Text(
              'عن النظام',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.water_drop, color: Colors.blue, size: 32),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نظام زمزم للفلاتر',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'إصدار 2.0.0',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'نظام ERP متكامل لإدارة شركات فلاتر المياه\nيشمل: المبيعات، التقسيط، التحصيلات، الصيانة، المخزون',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
