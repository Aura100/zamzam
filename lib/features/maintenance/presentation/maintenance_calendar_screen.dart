import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../users/data/users_repository.dart';
import 'maintenance_providers.dart';

class MaintenanceCalendarScreen extends ConsumerWidget {
  const MaintenanceCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(maintenanceRequestsStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final techniciansAsync = ref.watch(techniciansStreamProvider);
    final selectedGovernorate = ref.watch(maintenanceGovernorateFilterProvider);
    final selectedArea = ref.watch(maintenanceAreaFilterProvider);

    return AppLayout(
      title: 'كشف مواعيد الصيانة',
      child: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (allRequests) {
          // Only show pending & in-progress requests, sorted by date
          final upcoming = allRequests
              .where((r) => r.status != 'Completed')
              .toList()
            ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

          final customers = customersAsync.valueOrNull ?? [];
          final technicians = techniciansAsync.valueOrNull ?? [];

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

          // Apply geographical filters
          final filtered = upcoming.where((req) {
            final customer = customers.where((c) => c.id == req.customerId).firstOrNull;
            if (customer == null) return true; // Show requests without matched customer
            if (selectedGovernorate != null && customer.governorate != selectedGovernorate) return false;
            if (selectedArea != null && customer.area != selectedArea) return false;
            return true;
          }).toList();

          return Column(
            children: [
              // Geographical Filter Dropdowns
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
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
                          ref.read(maintenanceGovernorateFilterProvider.notifier).state = value;
                          // Reset area when governorate changes
                          ref.read(maintenanceAreaFilterProvider.notifier).state = null;
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
                          ref.read(maintenanceAreaFilterProvider.notifier).state = value;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Content
              Expanded(
                child: _buildContent(context, ref, filtered, customers, technicians),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<MaintenanceRequest> upcoming, List<Customer> customers, List<User> technicians) {
    if (upcoming.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا يوجد مواعيد صيانة قادمة.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group by date
    final Map<String, List<MaintenanceRequest>> grouped = {};
    for (final req in upcoming) {
      final key = '${req.scheduledDate.year}-${req.scheduledDate.month.toString().padLeft(2, '0')}-${req.scheduledDate.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(req);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (ctx, groupIndex) {
        final dateKey = grouped.keys.toList()[groupIndex];
        final dayRequests = grouped[dateKey]!;
        final parts = dateKey.split('-');
        final dateLabel = '${parts[2]}/${parts[1]}/${parts[0]}';

        final today = DateTime.now();
        final reqDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final isToday = reqDate.year == today.year && reqDate.month == today.month && reqDate.day == today.day;
        final isPast = reqDate.isBefore(DateTime(today.year, today.month, today.day));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8, top: 8),
              decoration: BoxDecoration(
                color: isToday
                    ? Colors.blue.shade700
                    : isPast
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isToday ? Colors.white : isPast ? Colors.red : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isToday ? 'اليوم - $dateLabel' : isPast ? 'متأخر - $dateLabel' : dateLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : isPast ? Colors.red.shade700 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${dayRequests.length} ${dayRequests.length == 1 ? 'طلب' : 'طلبات'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isToday ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Requests for this date
            ...dayRequests.map((req) {
              final customer = customers.where((c) => c.id == req.customerId).firstOrNull;
              final tech = technicians.where((t) => t.id == req.technicianId).firstOrNull;
              final statusColor = req.status == 'InProgress' ? Colors.orange : Colors.blue;

              return Card(
                margin: const EdgeInsets.only(bottom: 8, right: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(
                      req.isInternal ? Icons.business : Icons.home,
                      color: statusColor,
                    ),
                  ),
                  title: Text(customer?.name ?? 'عميل #${req.customerId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (customer?.address != null) Text('العنوان: ${customer!.address}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('المشكلة: ${req.issueDescription}'),
                      if (req.scheduledTime != null)
                        Text('الوقت: ${req.scheduledTime}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          const Icon(Icons.engineering, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            tech != null ? tech.name : 'لم يُعيَّن فني بعد',
                            style: TextStyle(color: tech != null ? Colors.green : Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (customer != null && customer.phone1.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.wechat, color: Colors.green, size: 28),
                          onPressed: () async {
                            final message = Uri.encodeComponent(
                              'عزيزي العميل ${customer.name}،\n'
                              'نود تذكيركم بموعد الصيانة الدورية للفلتر المستحقة بتاريخ $dateLabel.\n'
                              'برجاء التواصل معنا لتحديد الموعد المناسب.\n'
                              'شركة زمزم للفلاتر',
                            );
                            final url = Uri.parse("https://wa.me/2${customer.phone1}?text=$message");
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح واتساب')));
                              }
                            }
                          },
                          tooltip: 'مراسلة واتساب',
                        ),
                      Chip(
                        label: Text(
                          req.isInternal ? 'داخلية' : 'خارجية',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        backgroundColor: req.isInternal ? Colors.purple : Colors.teal,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
