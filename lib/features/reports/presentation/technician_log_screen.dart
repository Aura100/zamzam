import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../users/data/users_repository.dart';
import 'technician_log_providers.dart';

class TechnicianLogScreen extends ConsumerStatefulWidget {
  const TechnicianLogScreen({super.key});

  @override
  ConsumerState<TechnicianLogScreen> createState() => _TechnicianLogScreenState();
}

class _TechnicianLogScreenState extends ConsumerState<TechnicianLogScreen> {
  int? _selectedTechnicianId;

  @override
  Widget build(BuildContext context) {
    final techniciansAsync = ref.watch(techniciansStreamProvider);

    return AppLayout(
      title: 'سجل الفنيين',
      child: Column(
        children: [
          // Technician Selection Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.engineering, size: 40, color: Colors.blue),
                const SizedBox(width: 16),
                Expanded(
                  child: techniciansAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('خطأ: $e'),
                    data: (techs) => DropdownButtonFormField<int>(
                      value: _selectedTechnicianId,
                      decoration: const InputDecoration(
                        labelText: 'اختر الفني لعرض سجله',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search),
                      ),
                      items: techs.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedTechnicianId = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_selectedTechnicianId == null)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.manage_accounts, size: 100, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('يرجى اختيار فني من القائمة أعلاه لعرض السجل الخاص به.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            Expanded(child: _TechnicianDetailsView(technicianId: _selectedTechnicianId!)),
        ],
      ),
    );
  }
}

class _TechnicianDetailsView extends ConsumerWidget {
  final int technicianId;
  const _TechnicianDetailsView({required this.technicianId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(technicianCompletedRequestsProvider(technicianId));
    final paymentsAsync = ref.watch(technicianPaymentsProvider(technicianId));
    final movementsAsync = ref.watch(technicianMovementsProvider(technicianId));
    final custodyAsync = ref.watch(technicianCurrentCustodyProvider(technicianId));

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Summary Row
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryCard(
                  title: 'الصيانات المكتملة',
                  value: requestsAsync.when(
                    data: (reqs) => reqs.length.toString(),
                    loading: () => '...',
                    error: (_, __) => 'خطأ',
                  ),
                  icon: Icons.build_circle,
                  color: Colors.blue,
                ),
                _SummaryCard(
                  title: 'إجمالي التوريدات للشركة',
                  value: paymentsAsync.when(
                    data: (payments) {
                      final total = payments.fold(0.0, (sum, p) => sum + p.amountHandedOver);
                      return '${total.toStringAsFixed(1)} ج.م';
                    },
                    loading: () => '...',
                    error: (_, __) => 'خطأ',
                  ),
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                ),
                _SummaryCard(
                  title: 'إجمالي عمولات الفني',
                  value: paymentsAsync.when(
                    data: (payments) {
                      final total = payments.fold(0.0, (sum, p) => sum + p.commissionAmount);
                      return '${total.toStringAsFixed(1)} ج.م';
                    },
                    loading: () => '...',
                    error: (_, __) => 'خطأ',
                  ),
                  icon: Icons.monetization_on,
                  color: Colors.orange,
                ),
                _SummaryCard(
                  title: 'أنواع قطع العهدة الحالية',
                  value: custodyAsync.when(
                    data: (items) => items.length.toString(),
                    loading: () => '...',
                    error: (_, __) => 'خطأ',
                  ),
                  icon: Icons.inventory,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
          
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.assignment_turned_in), text: 'سجل الصيانات المكتملة'),
              Tab(icon: Icon(Icons.payments), text: 'سجل التوريدات المالية'),
              Tab(icon: Icon(Icons.history_toggle_off), text: 'حركة العهد والمرتجعات'),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              children: [
                _buildRequestsTab(requestsAsync),
                _buildPaymentsTab(paymentsAsync),
                _buildMovementsTab(movementsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(AsyncValue<List<MaintenanceRequest>> requestsAsync) {
    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (reqs) {
        if (reqs.isEmpty) return const Center(child: Text('لا توجد صيانات مكتملة لهذا الفني.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reqs.length,
          itemBuilder: (ctx, i) {
            final req = reqs[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.done_all, color: Colors.white)),
                title: Text('طلب صيانة #${req.id}'),
                subtitle: Text('تاريخ الانتهاء: ${req.completionDate?.toString().split('.').first ?? "غير معروف"} \nالأجزاء المستخدمة: ${req.partsUsed ?? "لا يوجد"}'),
                trailing: Text('${req.cost.toStringAsFixed(1)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentsTab(AsyncValue<List<MaintenancePayment>> paymentsAsync) {
    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (payments) {
        if (payments.isEmpty) return const Center(child: Text('لا توجد توريدات مالية مسجلة لهذا الفني.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (ctx, i) {
            final payment = payments[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.attach_money, color: Colors.white)),
                title: Text('طلب صيانة #${payment.requestId}'),
                subtitle: Text('تاريخ الدفع: ${payment.paymentDate.toString().split('.').first}\nالمحصل من العميل: ${payment.totalCollected} ج.م | عمولة الفني (${payment.commissionPercent}%): ${payment.commissionAmount} ج.م'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('المورد للشركة', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${payment.amountHandedOver.toStringAsFixed(1)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMovementsTab(AsyncValue<List<InventoryMovement>> movementsAsync) {
    return movementsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
      data: (movements) {
        if (movements.isEmpty) return const Center(child: Text('لا توجد حركة عهد مسجلة لهذا الفني.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: movements.length,
          itemBuilder: (ctx, i) {
            final mov = movements[i];
            final isOut = mov.type.contains('OUT') || mov.type.contains('DISPENSE');
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOut ? Colors.orange.shade100 : Colors.teal.shade100,
                  child: Icon(isOut ? Icons.arrow_outward : Icons.login, color: isOut ? Colors.orange : Colors.teal),
                ),
                title: Text(mov.notes ?? 'حركة مخزنية'),
                subtitle: Text('تاريخ: ${mov.date.toString().split('.').first}\nرقم المنتج: ${mov.productId}'),
                trailing: Text('الكمية: ${mov.quantity}', style: TextStyle(fontWeight: FontWeight.bold, color: isOut ? Colors.orange : Colors.teal)),
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
