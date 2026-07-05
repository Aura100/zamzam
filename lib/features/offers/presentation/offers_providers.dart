import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../data/offers_repository.dart';
import '../domain/offer_model.dart';

// Repository provider
final offersRepositoryProvider = Provider<OffersRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return OffersRepository(db);
});

// Get all offers
final allOffersProvider = FutureProvider<List<OfferModel>>((ref) async {
  final repo = ref.watch(offersRepositoryProvider);
  return repo.getAllOffers();
});

// Get active offers only
final activeOffersProvider = FutureProvider<List<OfferModel>>((ref) async {
  final repo = ref.watch(offersRepositoryProvider);
  return repo.getActiveOffers();
});

// Get single offer
final singleOfferProvider = FutureProvider.family<OfferModel?, int>((
  ref,
  offerId,
) async {
  final repo = ref.watch(offersRepositoryProvider);
  return repo.getOfferById(offerId);
});

// Get offer for a specific product
final productOfferProvider = FutureProvider.family<OfferItemModel?, int>((
  ref,
  productId,
) async {
  final repo = ref.watch(offersRepositoryProvider);
  return repo.getOfferForProduct(productId);
});

// State notifier for adding/updating offers
class OffersNotifier extends StateNotifier<AsyncValue<void>> {
  final OffersRepository repo;
  final Ref ref;

  OffersNotifier(this.repo, this.ref) : super(const AsyncValue.data(null));

  Future<void> createOffer({
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required List<OfferItemModel> items,
    int? createdBy,
    bool isBundle = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await repo.createOffer(
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        items: items,
        createdBy: createdBy,
        isBundle: isBundle,
      );
      state = const AsyncValue.data(null);
      // Refresh offers list
      ref.refresh(allOffersProvider);
      ref.refresh(activeOffersProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateOffer({
    required int offerId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required String status,
    required List<OfferItemModel> items,
    bool isBundle = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await repo.updateOffer(
        offerId: offerId,
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        status: status,
        items: items,
        isBundle: isBundle,
      );
      state = const AsyncValue.data(null);
      // Refresh offers list
      ref.refresh(allOffersProvider);
      ref.refresh(activeOffersProvider);
      ref.refresh(singleOfferProvider(offerId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteOffer(int offerId) async {
    state = const AsyncValue.loading();
    try {
      await repo.deleteOffer(offerId);
      state = const AsyncValue.data(null);
      // Refresh offers list
      ref.refresh(allOffersProvider);
      ref.refresh(activeOffersProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final offersNotifierProvider =
    StateNotifierProvider<OffersNotifier, AsyncValue<void>>((ref) {
      final repo = ref.watch(offersRepositoryProvider);
      return OffersNotifier(repo, ref);
    });
