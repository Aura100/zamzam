import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_layout.dart';
import '../domain/offer_model.dart';
import 'offers_providers.dart';
import 'add_edit_offer_screen.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allOffers = ref.watch(allOffersProvider);

    return AppLayout(
      title: 'العروض والتخفيفات',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEditOfferScreen()),
          );
        },
        label: const Text('عرض جديد'),
        icon: const Icon(Icons.add),
      ),
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(allOffersProvider.future),
        child: allOffers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('خطأ: $err')),
          data: (offers) {
            if (offers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد عروض حالياً',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AddEditOfferScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('إنشاء عرض جديد'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active offers section
                  if (offers.where((o) => o.isActive).isNotEmpty) ...[
                    Text(
                      'العروض النشطة',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    ..._buildOffersList(
                      context,
                      ref,
                      offers.where((o) => o.isActive).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Scheduled offers section
                  if (offers
                      .where((o) => !o.isActive && !o.isExpired)
                      .isNotEmpty) ...[
                    Text(
                      'العروض القادمة',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.blue),
                    ),
                    const SizedBox(height: 12),
                    ..._buildOffersList(
                      context,
                      ref,
                      offers.where((o) => !o.isActive && !o.isExpired).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Expired offers section
                  if (offers.where((o) => o.isExpired).isNotEmpty) ...[
                    Text(
                      'العروض المنتهية',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ..._buildOffersList(
                      context,
                      ref,
                      offers.where((o) => o.isExpired).toList(),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildOffersList(
    BuildContext context,
    WidgetRef ref,
    List<OfferModel> offers,
  ) {
    return offers
        .map((offer) {
          final statusColor = offer.isActive
              ? Colors.green
              : offer.isExpired
              ? Colors.grey
              : Colors.blue;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddEditOfferScreen(offerId: offer.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (offer.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  offer.description!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            offer.isActive
                                ? 'نشط'
                                : offer.isExpired
                                ? 'منتهي'
                                : 'قادم',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'من: ${_formatDate(offer.startDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'إلى: ${_formatDate(offer.endDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          '${offer.items.length} منتجات',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Products in offer
                    if (offer.items.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: offer.items.take(3).map((item) {
                          return Chip(
                            label: Text(
                              '${item.productName}: ${item.discountedPrice.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.blue.withOpacity(0.1),
                          );
                        }).toList(),
                      ),
                      if (offer.items.length > 3)
                        Text(
                          '... و${offer.items.length - 3} منتجات أخرى',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('حذف العرض'),
                                content: const Text('هل تريد حذف هذا العرض؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('حذف'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ref
                                  .read(offersNotifierProvider.notifier)
                                  .deleteOffer(offer.id);
                            }
                          },
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('حذف'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddEditOfferScreen(offerId: offer.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('تعديل'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        })
        .toList()
        .cast<Widget>();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
