import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../auth/presentation/auth_providers.dart';
import 'package:drift/drift.dart' as drift;

final openCashDrawerProvider = StreamProvider<CashDrawerSession?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.cashDrawerSessions)
        ..where((t) => t.isClosed.equals(false))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.openedAt)])
        ..limit(1))
      .watchSingleOrNull();
});

final cashDrawerHistoryProvider = StreamProvider<List<CashDrawerSession>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.cashDrawerSessions)
        ..where((t) => t.isClosed.equals(true))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.openedAt)])
        ..limit(30))
      .watch();
});

class CashDrawerScreen extends ConsumerStatefulWidget {
  const CashDrawerScreen({super.key});

  @override
  ConsumerState<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends ConsumerState<CashDrawerScreen> {
  final _openingBalanceCtrl = TextEditingController();
  final _closingBalanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _openingBalanceCtrl.dispose();
    _closingBalanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<double> _getTodayCashSales() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final invoices = await (db.select(db.salesInvoices)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(todayStart) &
              t.paymentType.equals('CASH')))
        .get();
    return invoices.fold<double>(0.0, (sum, i) => sum + i.totalAmount);
  }

  Future<void> _openDrawer() async {
    final opening = double.tryParse(_openingBalanceCtrl.text) ?? 0.0;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final db = ref.read(databaseProvider);
    await db.into(db.cashDrawerSessions).insert(
          CashDrawerSessionsCompanion.insert(
            openingBalance: drift.Value(opening),
            openedBy: user.id,
          ),
        );
    _openingBalanceCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ تم فتح الخزينة بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _closeDrawer(CashDrawerSession session) async {
    final cashSales = await _getTodayCashSales();
    final expectedBalance = session.openingBalance + cashSales;

    if (!mounted) return;

    _closingBalanceCtrl.text = expectedBalance.toStringAsFixed(2);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('إغلاق الخزينة'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('رصيد الفتح:', '${session.openingBalance.toStringAsFixed(2)} ج.م', Colors.blue),
                _infoRow('مبيعات كاش اليوم:', '${cashSales.toStringAsFixed(2)} ج.م', Colors.green),
                _infoRow('الرصيد المتوقع:', '${expectedBalance.toStringAsFixed(2)} ج.م', Colors.orange),
                const Divider(height: 24),
                TextField(
                  controller: _closingBalanceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الرصيد الفعلي في الخزينة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Builder(builder: (ctx) {
                  final actual = double.tryParse(_closingBalanceCtrl.text) ?? 0.0;
                  final diff = actual - expectedBalance;
                  final isShortage = diff < 0;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: diff == 0
                          ? Colors.green.shade50
                          : isShortage
                              ? Colors.red.shade50
                              : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          diff == 0
                              ? Icons.check_circle
                              : isShortage
                                  ? Icons.warning
                                  : Icons.arrow_upward,
                          color: diff == 0
                              ? Colors.green
                              : isShortage
                                  ? Colors.red
                                  : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          diff == 0
                              ? 'الخزينة مطابقة تماماً ✅'
                              : isShortage
                                  ? 'عجز: ${diff.abs().toStringAsFixed(2)} ج.م'
                                  : 'زيادة: ${diff.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: diff == 0
                                ? Colors.green
                                : isShortage
                                    ? Colors.red
                                    : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('إغلاق الخزينة'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final actual = double.tryParse(_closingBalanceCtrl.text) ?? 0.0;
                final db = ref.read(databaseProvider);
                await (db.update(db.cashDrawerSessions)
                      ..where((t) => t.id.equals(session.id)))
                    .write(CashDrawerSessionsCompanion(
                  actualClosingBalance: drift.Value(actual),
                  closedAt: drift.Value(DateTime.now()),
                  isClosed: const drift.Value(true),
                  notes: drift.Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
                ));
                _notesCtrl.clear();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم إغلاق الخزينة'), backgroundColor: Colors.green),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openSessionAsync = ref.watch(openCashDrawerProvider);
    final historyAsync = ref.watch(cashDrawerHistoryProvider);

    return AppLayout(
      title: 'إدارة الخزينة',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current session status
            openSessionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (session) {
                if (session == null) {
                  // Drawer is CLOSED
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock, size: 48, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          const Text('الخزينة مغلقة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Text('قم بفتح الخزينة لبدء يوم العمل', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _openingBalanceCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'رصيد فتح الخزينة (ج.م)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _openDrawer,
                                icon: const Icon(Icons.lock_open),
                                label: const Text('فتح الخزينة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Drawer is OPEN
                return FutureBuilder<double>(
                  future: _getTodayCashSales(),
                  builder: (ctx, snap) {
                    final cashSales = snap.data ?? 0.0;
                    final expectedBalance = session.openingBalance + cashSales;

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lock_open, size: 32, color: Colors.green),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('الخزينة مفتوحة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                      Text(
                                        'منذ: ${DateFormat('hh:mm a - yyyy/MM/dd').format(session.openedAt)}',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _closeDrawer(session),
                                  icon: const Icon(Icons.lock),
                                  label: const Text('إغلاق الخزينة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                _statCard('رصيد الفتح', '${session.openingBalance.toStringAsFixed(2)} ج.م', Icons.play_circle, Colors.blue),
                                const SizedBox(width: 12),
                                _statCard('مبيعات كاش اليوم', '${cashSales.toStringAsFixed(2)} ج.م', Icons.trending_up, Colors.green),
                                const SizedBox(width: 12),
                                _statCard('الرصيد المتوقع', '${expectedBalance.toStringAsFixed(2)} ج.م', Icons.account_balance_wallet, Colors.orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // History
            Text('سجل الخزينة (آخر 30 يوم)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ: $e'),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('لا يوجد سجل سابق', style: TextStyle(color: Colors.grey))),
                    ),
                  );
                }
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final s = sessions[i];
                      final diff = (s.actualClosingBalance ?? 0) - (s.openingBalance + 0); // simplified
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.history, color: Colors.blue),
                        ),
                        title: Text(DateFormat('yyyy/MM/dd').format(s.openedAt)),
                        subtitle: Text(
                          'فتح: ${s.openingBalance.toStringAsFixed(2)} ج.م  |  إغلاق فعلي: ${(s.actualClosingBalance ?? 0).toStringAsFixed(2)} ج.م',
                        ),
                        trailing: s.notes != null
                            ? Tooltip(
                                message: s.notes!,
                                child: const Icon(Icons.note, color: Colors.grey),
                              )
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
