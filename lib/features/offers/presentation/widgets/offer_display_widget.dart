import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/offer_model.dart';
import '../offers_providers.dart';

/// Widget to display active offers in a sales context
class OfferDisplayWidget extends ConsumerWidget {
  final int productId;
  final VoidCallback? onOfferApplied;

  const OfferDisplayWidget({
    super.key,
    required this.productId,
    this.onOfferApplied,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offerAsync = ref.watch(productOfferProvider(productId));

    return offerAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (offer) {
        if (offer == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'عرض متاح!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (offer.discountPercent != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'تخفيف ${offer.discountPercent?.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (offer.originalPrice != null)
                Row(
                  children: [
                    Text(
                      'السعر الأصلي: ${offer.originalPrice?.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 16),
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'السعر المخفض: ',
                            style: TextStyle(color: Colors.black, fontSize: 12),
                          ),
                          TextSpan(
                            text:
                                '${offer.discountedPrice.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Helper class to check if a product has an active offer
class OfferHelper {
  static Future<OfferItemModel?> getProductOffer(
    int productId,
    WidgetRef ref,
  ) async {
    return ref.read(productOfferProvider(productId).future);
  }

  static Future<List<OfferModel>> getActiveOffers(WidgetRef ref) async {
    return ref.read(activeOffersProvider.future);
  }

  static Future<List<OfferModel>> getAllOffers(WidgetRef ref) async {
    return ref.read(allOffersProvider.future);
  }
}
