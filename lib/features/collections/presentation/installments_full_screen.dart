import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../shared/services/whatsapp_service.dart';
import '../data/collections_repository.dart';
import 'collections_providers.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final allInstallmentsDetailsProvider =
    FutureProvider<List<InstallmentWithDetails>>((ref) async {
  final repo = ref.watch(collectionsRepositoryProvider);
  return repo.getAllInstallmentsWithDetails();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class InstallmentsFullScreen extends ConsumerStatefulWidget {
  const InstallmentsFullScreen({super.key});

  @override
  ConsumerState<InstallmentsFullScreen> createState() =>
      _InstallmentsFullScreenState();
}

class _InstallmentsFullScreenState
    extends ConsumerState<InstallmentsFullScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // all | pending | paid | late
  DateTime? _fromDate;
  DateTime? _toDate;
  late TabController _tabController;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat('#,##0.00', 'ar');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<InstallmentWithDetails> _applyFilters(List<InstallmentWithDetails> all) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return all.where((item) {
      final inst = item.installment;
      final customer = item.customer;

      // Tab filter
      switch (_tabController.index) {
        case 1: // Today
          final end = todayStart.add(const Duration(days: 1));
          if (inst.dueDate.isBefore(todayStart) ||
              !inst.dueDate.isBefore(end)) return false;
          break;
        case 2: // Overdue (unpaid & past)
          if (inst.status == 'Paid') return false;
          if (!inst.dueDate.isBefore(todayStart)) return false;
          break;
        case 3: // Paid
          if (inst.status != 'Paid') return false;
          break;
        default: // All
          break;
      }

      // Customer / contract search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = customer.name.toLowerCase().contains(q);
        final phoneMatch = customer.phone1.toLowerCase().contains(q);
        final contractMatch =
            item.contract.contractNumber.toLowerCase().contains(q);
        if (!nameMatch && !phoneMatch && !contractMatch) return false;
      }

      // Date range filter
      if (_fromDate != null &&
          inst.dueDate
              .isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) {
        return false;
      }
      if (_toDate != null &&
          inst.dueDate.isAfter(
              DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59))) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(allInstallmentsDetailsProvider);

    return AppLayout(
      title: 'جدول الأقساط والتحصيلات',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Filters Row ────────────────────────────────────────────────
            _buildFiltersRow(),
            const SizedBox(height: 12),
            // ── Tab Bar ────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.blue,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade700,
                tabs: const [
                  Tab(text: 'الكل'),
                  Tab(text: 'اليوم'),
                  Tab(text: 'المتأخرة'),
                  Tab(text: 'المدفوعة'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Summary Cards ──────────────────────────────────────────────
            dataAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (all) {
                final filtered = _applyFilters(all);
                return _buildSummaryCards(all, filtered);
              },
            ),
            const SizedBox(height: 12),
            // ── Table ──────────────────────────────────────────────────────
            Expanded(
              child: dataAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('خطأ في تحميل البيانات: $e')),
                data: (all) {
                  final filtered = _applyFilters(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('لا يوجد نتائج',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 18)),
                        ],
                      ),
                    );
                  }
                  return _buildTable(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filters Row ─────────────────────────────────────────────────────────────

  Widget _buildFiltersRow() {
    return Row(
      children: [
        // Search
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث باسم العميل أو الهاتف أو رقم العقد...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(width: 12),
        // From Date
        _DatePickerButton(
          label: _fromDate != null ? 'من: ${_dateFormat.format(_fromDate!)}' : 'من تاريخ',
          icon: Icons.calendar_today,
          onTap: () => _pickDate(true),
          onClear: _fromDate != null ? () => setState(() => _fromDate = null) : null,
        ),
        const SizedBox(width: 8),
        // To Date
        _DatePickerButton(
          label: _toDate != null ? 'إلى: ${_dateFormat.format(_toDate!)}' : 'إلى تاريخ',
          icon: Icons.calendar_month,
          color: Colors.indigo,
          onTap: () => _pickDate(false),
          onClear: _toDate != null ? () => setState(() => _toDate = null) : null,
        ),
        const SizedBox(width: 8),
        // Refresh
        IconButton.filled(
          onPressed: () => ref.invalidate(allInstallmentsDetailsProvider),
          icon: const Icon(Icons.refresh),
          tooltip: 'تحديث البيانات',
        ),
      ],
    );
  }

  // ── Summary Cards ────────────────────────────────────────────────────────────

  Widget _buildSummaryCards(
      List<InstallmentWithDetails> all, List<InstallmentWithDetails> filtered) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    double totalPending = 0;
    double totalPaid = 0;
    double totalOverdue = 0;
    int overdueCount = 0;

    for (final item in filtered) {
      final inst = item.installment;
      final remaining = inst.amount - inst.partialPaidAmount;
      if (inst.status == 'Paid') {
        totalPaid += inst.amount;
      } else {
        totalPending += remaining;
        if (inst.dueDate.isBefore(todayStart)) {
          totalOverdue += remaining;
          overdueCount++;
        }
      }
    }

    return Row(
      children: [
        _SummaryCard(
          label: 'إجمالي المعروض',
          value: '${filtered.length} قسط',
          icon: Icons.list_alt,
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          label: 'إجمالي المستحق',
          value: '${_currencyFormat.format(totalPending)} ج.م',
          icon: Icons.account_balance_wallet,
          color: Colors.orange,
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          label: 'متأخرات ($overdueCount قسط)',
          value: '${_currencyFormat.format(totalOverdue)} ج.م',
          icon: Icons.warning_amber,
          color: Colors.red,
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          label: 'تم تحصيله',
          value: '${_currencyFormat.format(totalPaid)} ج.م',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
      ],
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────────

  Widget _buildTable(List<InstallmentWithDetails> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
            headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.blue),
            dividerThickness: 0.5,
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('العميل')),
              DataColumn(label: Text('الهاتف')),
              DataColumn(label: Text('رقم العقد')),
              DataColumn(label: Text('القسط')),
              DataColumn(label: Text('المدفوع')),
              DataColumn(label: Text('المتبقي')),
              DataColumn(label: Text('تاريخ الاستحقاق')),
              DataColumn(label: Text('الحالة')),
              DataColumn(label: Text('إجراءات')),
            ],
            rows: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final inst = item.installment;
              final customer = item.customer;
              final remaining = inst.amount - inst.partialPaidAmount;
              final isOverdue = inst.status != 'Paid' &&
                  inst.dueDate.isBefore(todayStart);
              final isToday = !inst.dueDate.isBefore(todayStart) &&
                  inst.dueDate
                      .isBefore(todayStart.add(const Duration(days: 1)));

              Color rowColor = Colors.white;
              if (isOverdue) rowColor = Colors.red.shade50;
              if (isToday && inst.status != 'Paid') rowColor = Colors.orange.shade50;
              if (inst.status == 'Paid') rowColor = Colors.green.shade50;

              return DataRow(
                color: WidgetStateProperty.all(rowColor),
                cells: [
                  DataCell(Text('${idx + 1}',
                      style: TextStyle(color: Colors.grey.shade500))),
                  DataCell(Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0]
                              : '?',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text(customer.name,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  )),
                  DataCell(Text(customer.phone1,
                      style: const TextStyle(fontFamily: 'monospace'))),
                  DataCell(Text(item.contract.contractNumber,
                      style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${_currencyFormat.format(inst.amount)} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(
                      '${_currencyFormat.format(inst.partialPaidAmount)} ج.م',
                      style: TextStyle(color: Colors.green.shade700))),
                  DataCell(Text('${_currencyFormat.format(remaining)} ج.م',
                      style: TextStyle(
                          color: remaining > 0
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontWeight: FontWeight.bold))),
                  DataCell(Text(_dateFormat.format(inst.dueDate),
                      style: TextStyle(
                          color: isOverdue ? Colors.red : null,
                          fontWeight: isOverdue || isToday
                              ? FontWeight.bold
                              : null))),
                  DataCell(_StatusChip(status: inst.status, isOverdue: isOverdue)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WhatsApp
                        if (customer.phone1.isNotEmpty)
                          Tooltip(
                            message: 'إرسال واتساب',
                            child: InkWell(
                              onTap: () {
                                WhatsAppService.sendMessage(
                                  phone: customer.phone1,
                                  message:
                                      WhatsAppService.installmentReminderMessage(
                                    customerName: customer.name,
                                    amount: remaining,
                                    dueDate: _dateFormat
                                        .format(inst.dueDate),
                                    installmentNumber: inst.id,
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.chat,
                                    color: Colors.green, size: 20),
                              ),
                            ),
                          ),
                        // Collect Payment
                        if (inst.status != 'Paid')
                          Tooltip(
                            message: 'تحصيل',
                            child: InkWell(
                              onTap: () =>
                                  _showCollectDialog(item, remaining),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('تحصيل',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Collect Dialog ───────────────────────────────────────────────────────────

  void _showCollectDialog(InstallmentWithDetails item, double remaining) {
    final ctrl = TextEditingController(text: remaining.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.payment, color: Colors.blue),
            const SizedBox(width: 8),
            Flexible(child: Text('تحصيل قسط - ${item.customer.name}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('رقم العقد:', item.contract.contractNumber),
            _InfoRow('القسط كاملاً:', '${_currencyFormat.format(item.installment.amount)} ج.م'),
            _InfoRow('المدفوع:', '${_currencyFormat.format(item.installment.partialPaidAmount)} ج.م'),
            _InfoRow('المتبقي:', '${_currencyFormat.format(remaining)} ج.م'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'المبلغ المحصل الآن',
                border: OutlineInputBorder(),
                suffixText: 'ج.م',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('تأكيد التحصيل'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            onPressed: () async {
              final paid = double.tryParse(ctrl.text) ?? 0.0;
              if (paid <= 0 && remaining > 0.01) return;
              await ref.read(collectionsRepositoryProvider).collectPayment(
                    installmentId: item.installment.id,
                    amountPaid: paid,
                    receiptNumber:
                        'REC-${DateTime.now().millisecondsSinceEpoch}',
                    collectorId: 1,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(allInstallmentsDetailsProvider);
            },
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _DatePickerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(120)),
          borderRadius: BorderRadius.circular(8),
          color: color.withAlpha(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 16, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withAlpha(40),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isOverdue;
  const _StatusChip({required this.status, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    if (status == 'Paid') {
      label = 'مدفوع';
      color = Colors.green;
    } else if (isOverdue) {
      label = 'متأخر';
      color = Colors.red;
    } else {
      label = 'قيد الانتظار';
      color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style:
              TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
