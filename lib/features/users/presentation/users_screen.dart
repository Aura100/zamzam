import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../data/users_repository.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersStreamProvider);

    return AppLayout(
      title: 'إدارة المستخدمين',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('قائمة المستخدمين', style: Theme.of(context).textTheme.titleLarge),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context, ref),
                  icon: const Icon(Icons.person_add),
                  label: const Text('مستخدم جديد'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: usersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (users) => ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final u = users[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(u.role).withOpacity(0.15),
                          child: Icon(Icons.person, color: _roleColor(u.role)),
                        ),
                        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_roleLabel(u.role)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.lock_reset, color: Colors.blue),
                              tooltip: 'تغيير الرقم السري',
                              onPressed: () => _showChangePinDialog(context, ref, u),
                            ),
                            if (u.role != 'Administrator')
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'حذف المستخدم',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تأكيد الحذف'),
                                      content: Text('هل تريد حذف المستخدم "${u.name}"؟'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await ref.read(usersRepositoryProvider).deleteUser(u.id);
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String role = 'Sales';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إضافة مستخدم جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المستخدم *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'الدور الوظيفي', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Sales', child: Text('مبيعات')),
                  DropdownMenuItem(value: 'Collector', child: Text('محصل')),
                  DropdownMenuItem(value: 'Warehouse', child: Text('مخزن')),
                  DropdownMenuItem(value: 'Technician', child: Text('فني صيانة')),
                  DropdownMenuItem(value: 'Manager', child: Text('مدير')),
                  DropdownMenuItem(value: 'Administrator', child: Text('مدير النظام')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'Sales'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: 'رقم PIN (4 أرقام) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || pinCtrl.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء جميع الحقول')));
                  return;
                }
                await ref.read(usersRepositoryProvider).addUser(
                  UsersCompanion.insert(name: nameCtrl.text.trim(), role: role, pinCode: pinCtrl.text),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة المستخدم'), backgroundColor: Colors.green));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref, User user) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تغيير رقم PIN لـ ${user.name}'),
        content: TextField(
          controller: pinCtrl,
          decoration: const InputDecoration(labelText: 'الرقم السري الجديد (4 أرقام)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (pinCtrl.text.length < 4) return;
              await ref.read(usersRepositoryProvider).updateUserPin(user.id, pinCtrl.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الرقم السري'), backgroundColor: Colors.green));
              }
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Administrator': return Colors.red;
      case 'Manager': return Colors.purple;
      case 'Sales': return Colors.blue;
      case 'Collector': return Colors.green;
      case 'Technician': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'Administrator': return 'مدير النظام';
      case 'Manager': return 'مدير';
      case 'Sales': return 'مبيعات';
      case 'Collector': return 'محصل';
      case 'Technician': return 'فني صيانة';
      case 'Warehouse': return 'مخزن';
      default: return role;
    }
  }
}
