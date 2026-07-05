import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import 'expenses_providers.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return AppLayout(
      title: 'إدارة المصروفات',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'البحث عن مصروف...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddExpenseDialog(context, ref);
                  },
                  icon: const Icon(Icons.money_off),
                  label: const Text('تسجيل مصروف جديد'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: expensesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('خطأ: $err')),
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const Center(child: Text('لا يوجد مصروفات مسجلة.'));
                    }
                    return ListView.separated(
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final exp = expenses[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.money_off, color: Colors.white),
                          ),
                          title: Text(exp.category),
                          subtitle: Text(exp.description ?? ''),
                          trailing: Text('${exp.amount} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'رواتب';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('تسجيل مصروف جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'بند المصروف', border: OutlineInputBorder()),
                  items: ['رواتب', 'إيجار', 'انتقالات', 'كهرباء', 'صيانة', 'تسويق', 'أخرى']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'البيان/الوصف', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (amount > 0) {
                    await ref.read(expensesRepositoryProvider).addExpense(
                      ExpensesCompanion.insert(
                        category: selectedCategory,
                        amount: amount,
                        description: drift.Value(descriptionController.text),
                      ),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        }
      ),
    );
  }
}
