import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../shared/services/whatsapp_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../customers/presentation/customers_providers.dart';
import '../data/collections_repository.dart';
import 'collections_providers.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayInstallmentsProvider);
    final overdueAsync = ref.watch(overdueInstallmentsProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final selectedGovernorate = ref.watch(collectionsGovernorateFilterProvider);
    final selectedArea = ref.watch(collectionsAreaFilterProvider);

    final customers = customersAsync.valueOrNull ?? [];

    // Build governorate and area lists from customers
    final governorates = customers
        .where((c) => c.governorate != null && c.governorate!.isNotEmpty)
        .map((c) => c.governorate!)
        .toSet()
        .toList()
      ..sort();
    final areas = customers
        .where((c) => c.area != null && c.area!.isNotEmpty)
        .where((c) => selectedGovernorate == null || c.governorate == selectedGovernorate)
        .map((c) => c.area!)
        .toSet()
        .toList()
      ..sort();

    return AppLayout(
      title: 'إدارة التحصيلات',
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Geographical Filter Dropdowns
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedGovernorate,
                      decoration: const InputDecoration(
                        labelText: 'المحافظة',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('الكل')),
                        ...governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))),
                      ],
                      onChanged: (value) {
                        ref.read(collectionsGovernorateFilterProvider.notifier).state = value;
                        // Reset area when governorate changes
                        ref.read(collectionsAreaFilterProvider.notifier).state = null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedArea,
                      decoration: const InputDecoration(
                        labelText: 'المنطقة',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('الكل')),
                        ...areas.map((a) => DropdownMenuItem(value: a, child: Text(a))),
                      ],
                      onChanged: (value) {
                        ref.read(collectionsAreaFilterProvider.notifier).state = value;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const TabBar(
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'تحصيلات اليوم'),
                  Tab(text: 'متأخرات'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    // Today
                    Card(
                      child: todayAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text('خطأ: $err')),
                        data: (installments) {
                          final filtered = installments.where((instWithDetails) {
                            final customer = instWithDetails.customer;
                            if (selectedGovernorate != null && customer.governorate != selectedGovernorate) return false;
                            if (selectedArea != null && customer.area != selectedArea) return false;
                            return true;
                          }).toList();
                          if (filtered.isEmpty) return const Center(child: Text('لا يوجد تحصيلات مستحقة.'));
                          return _buildList(context, ref, filtered);
                        },
                      ),
                    ),
                    // Overdue
                    Card(
                      child: overdueAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text('خطأ: $err')),
                        data: (installments) {
                          final filtered = installments.where((instWithDetails) {
                            final customer = instWithDetails.customer;
                            if (selectedGovernorate != null && customer.governorate != selectedGovernorate) return false;
                            if (selectedArea != null && customer.area != selectedArea) return false;
                            return true;
                          }).toList();
                          if (filtered.isEmpty) return const Center(child: Text('لا يوجد أقساط متأخرة.'));
                          return _buildList(context, ref, filtered);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<InstallmentWithDetails> installments) {
    return ListView.separated(
      itemCount: installments.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final detail = installments[index];
        final inst = detail.installment;
        final customer = detail.customer;
        final remainingToPay = inst.amount - inst.partialPaidAmount;
        
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('${customer.name} (عقد: ${inst.contractId})'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المستحق: $remainingToPay ج.م - تاريخ الاستحقاق: ${inst.dueDate.day}/${inst.dueDate.month}/${inst.dueDate.year}'),
              if (customer.address != null && customer.address!.isNotEmpty)
                Text('العنوان: ${customer.address}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.wechat, color: Colors.green, size: 28),
                onPressed: () {
                  if (customer.phone1.isNotEmpty) {
                    WhatsAppService.sendMessage(
                      phone: customer.phone1,
                      message: WhatsAppService.installmentReminderMessage(
                        customerName: customer.name,
                        amount: remainingToPay,
                        dueDate: '${inst.dueDate.day}/${inst.dueDate.month}/${inst.dueDate.year}',
                        installmentNumber: 1, // Currently not stored in DB
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا يوجد رقم هاتف متاح لهذا العميل')),
                    );
                  }
                },
                tooltip: 'مراسلة واتساب',
              ),
              ElevatedButton(
                onPressed: () {
                  _showCollectDialog(context, ref, inst, remainingToPay);
                },
                child: const Text('تحصيل'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCollectDialog(BuildContext context, WidgetRef ref, dynamic inst, double amount) {
    final amountController = TextEditingController(text: amount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحصيل قسط'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'المبلغ المحصل', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final paid = double.tryParse(amountController.text) ?? 0.0;
              await ref.read(collectionsRepositoryProvider).collectPayment(
                installmentId: inst.id,
                amountPaid: paid,
                receiptNumber: 'REC-${DateTime.now().millisecondsSinceEpoch}',
                collectorId: 1, // Currently hardcoded to 1
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('تأكيد التحصيل'),
          ),
        ],
      ),
    );
  }
}
