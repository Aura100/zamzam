import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/database_provider.dart';
import 'hr_providers.dart';

class HRDashboardScreen extends ConsumerWidget {
  const HRDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeWithUserProvider);

    return AppLayout(
      title: 'الموارد البشرية والرواتب',
      child: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (employees) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.push('/hr/payroll-processing'),
                      icon: const Icon(Icons.payment),
                      label: const Text('إصدار كشف رواتب الشهر'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final item = employees[index];
                    final EmployeeProfile profile = item['profile'];
                    final User user = item['user'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user.name),
                        subtitle: Text('الراتب الأساسي: ${profile.baseSalary} ج.م | الحالة: ${profile.status}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              tooltip: 'إضافة مكافأة/سلفة',
                              onPressed: () {
                                _showAddTransactionDialog(context, ref, profile.id, user.name);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'تعديل الملف',
                              onPressed: () {
                                _showEditProfileDialog(context, ref, profile, user);
                              },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           _showCreateProfileDialog(context, ref);
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref, int employeeId, String empName) {
    String type = 'BONUS';
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('إضافة حركة مالية - $empName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'BONUS', child: Text('مكافأة (+)')),
                  DropdownMenuItem(value: 'DEDUCTION', child: Text('خصم/جزاء (-)')),
                  DropdownMenuItem(value: 'ADVANCE', child: Text('سلفة (-)')),
                ],
                onChanged: (v) => setState(() => type = v!),
                decoration: const InputDecoration(labelText: 'النوع'),
              ),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'المبلغ'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'الوصف/السبب'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount > 0) {
                  await ref.read(hrRepositoryProvider).addTransaction(
                    PayrollTransactionsCompanion.insert(
                      employeeId: employeeId,
                      type: type,
                      amount: amount,
                      description: drift.Value(descCtrl.text),
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم الإضافة بنجاح')));
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, EmployeeProfile profile, User user) {
    final salaryCtrl = TextEditingController(text: profile.baseSalary.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل ملف ${user.name}'),
        content: TextField(
          controller: salaryCtrl,
          decoration: const InputDecoration(labelText: 'الراتب الأساسي'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final newSalary = double.tryParse(salaryCtrl.text) ?? 0;
              await ref.read(hrRepositoryProvider).createOrUpdateProfile(
                EmployeeProfilesCompanion(
                  id: drift.Value(profile.id),
                  baseSalary: drift.Value(newSalary),
                )
              );
              if (ctx.mounted) {
                ref.invalidate(employeeWithUserProvider);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showCreateProfileDialog(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final users = await db.select(db.users).get();
    
    if (context.mounted) {
      int? selectedUserId;
      final salaryCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('إنشاء ملف موظف جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedUserId,
                  items: users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                  onChanged: (v) => setState(() => selectedUserId = v),
                  decoration: const InputDecoration(labelText: 'اختر المستخدم'),
                ),
                TextField(
                  controller: salaryCtrl,
                  decoration: const InputDecoration(labelText: 'الراتب الأساسي'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final salary = double.tryParse(salaryCtrl.text) ?? 0;
                  if (selectedUserId != null) {
                    await ref.read(hrRepositoryProvider).createOrUpdateProfile(
                      EmployeeProfilesCompanion.insert(
                        userId: selectedUserId!,
                        baseSalary: drift.Value(salary),
                      )
                    );
                    if (ctx.mounted) {
                      ref.invalidate(employeeWithUserProvider);
                      Navigator.pop(ctx);
                    }
                  }
                },
                child: const Text('إنشاء'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
