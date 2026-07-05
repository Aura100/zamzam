import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';
import '../domain/commission_utils.dart';

class TechnicianCommission {
  final int technicianId;
  final String technicianName;
  final int completedJobs;
  final double totalCost;
  final double commissionPercent;
  final double commission;

  TechnicianCommission({
    required this.technicianId,
    required this.technicianName,
    required this.completedJobs,
    required this.totalCost,
    required this.commissionPercent,
    required this.commission,
  });
}

final commissionReportProvider =
    FutureProvider.family<List<TechnicianCommission>, DateTimeRange>((
      ref,
      range,
    ) async {
      final db = ref.watch(databaseProvider);

      final technicians = await (db.select(
        db.users,
      )..where((t) => t.role.equals('Technician'))).get();
      final rates = await (db.select(db.technicianCommissionRates)).get();
      final rateMap = {
        for (final rate in rates) rate.technicianId: rate.commissionPercent,
      };

      final requests =
          await (db.select(db.maintenanceRequests)..where(
                (t) =>
                    t.status.equals('Completed') &
                    t.completionDate.isBiggerOrEqualValue(range.start) &
                    t.completionDate.isSmallerThanValue(
                      range.end.add(const Duration(days: 1)),
                    ),
              ))
              .get();

      final results = <TechnicianCommission>[];

      for (final tech in technicians) {
        final techRequests = requests
            .where((r) => r.technicianId == tech.id)
            .toList();
        final totalCost = techRequests.fold(0.0, (sum, r) => sum + r.cost);
        final commissionPercent = rateMap[tech.id] ?? 10.0;
        final commission = calculateCommissionAmount(
          totalCost,
          commissionPercent,
        );

        results.add(
          TechnicianCommission(
            technicianId: tech.id,
            technicianName: tech.name,
            completedJobs: techRequests.length,
            totalCost: totalCost,
            commissionPercent: commissionPercent,
            commission: commission,
          ),
        );
      }

      return results;
    });

class CommissionsReportScreen extends ConsumerStatefulWidget {
  const CommissionsReportScreen({super.key});

  @override
  ConsumerState<CommissionsReportScreen> createState() =>
      _CommissionsReportScreenState();
}

class _CommissionsReportScreenState
    extends ConsumerState<CommissionsReportScreen> {
  late DateTimeRange _dateRange;
  final Map<int, TextEditingController> _percentControllers = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  @override
  void dispose() {
    for (final controller in _percentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commissionsAsync = ref.watch(commissionReportProvider(_dateRange));

    return AppLayout(
      title: 'تقرير عمولات الفنيين',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      'من: ${DateFormat('yyyy-MM-dd').format(_dateRange.start)}  إلى: ${DateFormat('yyyy-MM-dd').format(_dateRange.end)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: _dateRange,
                        );
                        if (picked != null) {
                          setState(() => _dateRange = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('تغيير الفترة'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: commissionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('خطأ: $e')),
                data: (commissions) {
                  if (commissions.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا يوجد فنيين مسجلين.',
                        style: TextStyle(fontSize: 18),
                      ),
                    );
                  }

                  for (final commission in commissions) {
                    _percentControllers.putIfAbsent(
                      commission.technicianId,
                      () => TextEditingController(
                        text: commission.commissionPercent.toStringAsFixed(1),
                      ),
                    );
                  }

                  final totalCommission = commissions.fold(
                    0.0,
                    (sum, c) => sum + c.commission,
                  );

                  return Column(
                    children: [
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تحديد العمولة لكل فني',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'أدخل نسبة العمولة لكل فني من إجمالي المبلغ المحصل.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 12),
                              ...commissions.map((commission) {
                                final controller =
                                    _percentControllers[commission
                                        .technicianId]!;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          commission.technicianName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 110,
                                        child: TextField(
                                          controller: controller,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'النسبة %',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _saveCommissionRate(
                                          commission.technicianId,
                                          controller.text,
                                        ),
                                        icon: const Icon(Icons.save),
                                        label: const Text('حفظ'),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _summaryItem(
                                'إجمالي الفنيين',
                                '${commissions.length}',
                                Icons.engineering,
                              ),
                              _summaryItem(
                                'إجمالي الأعمال',
                                '${commissions.fold(0, (sum, c) => sum + c.completedJobs)}',
                                Icons.build,
                              ),
                              _summaryItem(
                                'إجمالي العمولات',
                                '${totalCommission.toStringAsFixed(0)} ج.م',
                                Icons.monetization_on,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Card(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('الفني')),
                                  DataColumn(label: Text('الأعمال المنجزة')),
                                  DataColumn(label: Text('إجمالي التكلفة')),
                                  DataColumn(label: Text('نسبة العمولة')),
                                  DataColumn(label: Text('العمولة المستحقة')),
                                ],
                                rows: commissions
                                    .map(
                                      (c) => DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              c.technicianName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text('${c.completedJobs}')),
                                          DataCell(
                                            Text(
                                              '${c.totalCost.toStringAsFixed(0)} ج.م',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${c.commissionPercent.toStringAsFixed(1)}%',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${c.commission.toStringAsFixed(0)} ج.م',
                                              style: TextStyle(
                                                color: c.commission > 0
                                                    ? Colors.green.shade700
                                                    : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCommissionRate(int technicianId, String value) async {
    final percent = double.tryParse(value);
    if (percent == null || percent < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل نسبة صحيحة للعمولة')),
        );
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final existing = await (db.select(
      db.technicianCommissionRates,
    )..where((t) => t.technicianId.equals(technicianId))).getSingleOrNull();

    if (existing == null) {
      await db
          .into(db.technicianCommissionRates)
          .insert(
            TechnicianCommissionRatesCompanion.insert(
              technicianId: technicianId,
              commissionPercent: drift.Value(percent),
            ),
          );
    } else {
      await (db.update(
        db.technicianCommissionRates,
      )..where((t) => t.technicianId.equals(technicianId))).write(
        TechnicianCommissionRatesCompanion(
          commissionPercent: drift.Value(percent),
        ),
      );
    }

    ref.invalidate(commissionReportProvider(_dateRange));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ نسبة العمولة لـ ${percent.toStringAsFixed(1)}%',
          ),
        ),
      );
    }
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.teal),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
