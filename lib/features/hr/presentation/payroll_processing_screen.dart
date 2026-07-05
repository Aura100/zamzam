import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';
import 'hr_providers.dart';

class PayrollProcessingScreen extends ConsumerStatefulWidget {
  const PayrollProcessingScreen({super.key});

  @override
  ConsumerState<PayrollProcessingScreen> createState() => _PayrollProcessingScreenState();
}

class _PayrollProcessingScreenState extends ConsumerState<PayrollProcessingScreen> {
  final _monthController = TextEditingController(text: DateFormat('yyyy-MM').format(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'إصدار الرواتب',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _monthController,
                    decoration: const InputDecoration(labelText: 'شهر الإصدار (مثال: 2023-10)'),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    final month = _monthController.text;
                    if (month.isNotEmpty) {
                      await ref.read(hrRepositoryProvider).closePayrollForMonth(month);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إصدار الرواتب وإغلاق الحركات بنجاح')));
                        // ignore: unused_result
                        ref.refresh(employeeWithUserProvider);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('إغلاق رواتب الشهر'),
                )
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder(
                future: _getPayrollsForMonth(_monthController.text, ref),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('خطأ: ${snapshot.error}'));
                  }
                  
                  final payrolls = snapshot.data as List<Map<String, dynamic>>? ?? [];
                  if (payrolls.isEmpty) {
                    return const Center(child: Text('لم يتم إصدار رواتب لهذا الشهر بعد.'));
                  }

                  return ListView.builder(
                    itemCount: payrolls.length,
                    itemBuilder: (context, index) {
                      final p = payrolls[index]['payroll'];
                      final uName = payrolls[index]['userName'];
                      return Card(
                        child: ListTile(
                          title: Text(uName),
                          subtitle: Text('الأساسي: ${p.baseSalary} | المكافآت: ${p.totalBonuses} | الخصومات: ${p.totalDeductions}'),
                          trailing: Text('الصافي: ${p.netSalary} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getPayrollsForMonth(String monthYear, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final results = await (db.select(db.monthlyPayrolls)
          ..where((t) => t.monthYear.equals(monthYear)))
        .join([
      drift.innerJoin(db.employeeProfiles, db.employeeProfiles.id.equalsExp(db.monthlyPayrolls.employeeId)),
      drift.innerJoin(db.users, db.users.id.equalsExp(db.employeeProfiles.userId)),
    ]).get();

    return results.map((row) {
      return {
        'payroll': row.readTable(db.monthlyPayrolls),
        'userName': row.readTable(db.users).name,
      };
    }).toList();
  }
}
