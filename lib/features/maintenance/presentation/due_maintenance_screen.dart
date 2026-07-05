import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/services/whatsapp_service.dart';
import 'maintenance_providers.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../users/data/users_repository.dart';
import 'package:drift/drift.dart' as drift;

final dueMaintSchedulesProvider = StreamProvider<List<MaintenanceSchedule>>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  return (db.select(db.maintenanceSchedules)
        ..where((t) =>
            t.status.equals('Active') &
            t.nextMaintenanceDate.isSmallerOrEqualValue(now.add(const Duration(days: 7)))))
      .watch();
});

class DueMaintenanceScreen extends ConsumerWidget {
  const DueMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(dueMaintSchedulesProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final now = DateTime.now();

    return AppLayout(
      title: 'الصيانات المستحقة والقادمة',
      child: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (schedules) {
          final customers = customersAsync.valueOrNull ?? [];

          if (schedules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text('لا توجد صيانات مستحقة خلال الأسبوع القادم 🎉',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final overdue = schedules.where((s) => s.nextMaintenanceDate.isBefore(now)).toList();
          final upcoming = schedules.where((s) => !s.nextMaintenanceDate.isBefore(now)).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.orange.shade500],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('${overdue.length}', 'متأخرة', Icons.warning),
                      _stat('${upcoming.length}', 'هذا الأسبوع', Icons.schedule),
                      _stat('${schedules.length}', 'الإجمالي', Icons.list),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (overdue.isNotEmpty) ...[
                  _sectionHeader(context, '⚠️ صيانات متأخرة (${overdue.length})', Colors.red),
                  const SizedBox(height: 8),
                  ...overdue.map((s) => _scheduleCard(context, ref, s, customers, isOverdue: true)),
                  const SizedBox(height: 16),
                ],

                if (upcoming.isNotEmpty) ...[
                  _sectionHeader(context, '📅 مستحقة هذا الأسبوع (${upcoming.length})', Colors.orange),
                  const SizedBox(height: 8),
                  ...upcoming.map((s) => _scheduleCard(context, ref, s, customers, isOverdue: false)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _scheduleCard(
    BuildContext context,
    WidgetRef ref,
    MaintenanceSchedule schedule,
    List<Customer> customers, {
    required bool isOverdue,
  }) {
    final customer = customers.where((c) => c.id == schedule.customerId).firstOrNull;
    final daysOverdue = DateTime.now().difference(schedule.nextMaintenanceDate).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? Colors.red.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isOverdue ? Colors.red.shade50 : Colors.orange.shade50,
              child: Icon(
                Icons.build,
                color: isOverdue ? Colors.red : Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'عميل رقم ${schedule.customerId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'موعد الصيانة: ${DateFormat('yyyy/MM/dd').format(schedule.nextMaintenanceDate)}',
                    style: TextStyle(color: isOverdue ? Colors.red : Colors.orange),
                  ),
                  if (isOverdue)
                    Text(
                      'متأخر بـ $daysOverdue يوم',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  if (customer?.phone1 != null)
                    Text('📞 ${customer!.phone1}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              children: [
                // WhatsApp button
                if (customer?.phone1 != null)
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.green),
                    tooltip: 'إرسال واتساب',
                    onPressed: () {
                      WhatsAppService.sendMessage(
                        phone: customer!.phone1,
                        message: WhatsAppService.maintenanceDueMessage(customerName: customer.name),
                      );
                    },
                  ),
                // Create maintenance request
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_task, size: 16),
                  label: const Text('إنشاء طلب'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _createMaintenanceRequest(context, ref, schedule, customer),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createMaintenanceRequest(
    BuildContext context,
    WidgetRef ref,
    MaintenanceSchedule schedule,
    Customer? customer,
  ) async {
    final db = ref.read(databaseProvider);
    await db.into(db.maintenanceRequests).insert(
          MaintenanceRequestsCompanion.insert(
            customerId: schedule.customerId,
            issueDescription: 'صيانة دورية - عقد جدولة رقم ${schedule.id}',
            scheduledDate: DateTime.now().add(const Duration(days: 1)),
            status: const drift.Value('Pending'),
          ),
        );

    // Update the schedule's last maintenance date
    await (db.update(db.maintenanceSchedules)..where((t) => t.id.equals(schedule.id))).write(
      MaintenanceSchedulesCompanion(
        lastMaintenanceDate: drift.Value(DateTime.now()),
        nextMaintenanceDate: drift.Value(
          DateTime.now().add(Duration(days: schedule.cycleMonths * 30)),
        ),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم إنشاء طلب صيانة للعميل ${customer?.name ?? ''}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
