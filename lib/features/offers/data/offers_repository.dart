import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../domain/offer_model.dart';

class OffersRepository {
  final AppDatabase db;

  OffersRepository(this.db);

  // Get all active offers
  Future<List<OfferModel>> getActiveOffers() async {
    final now = DateTime.now();
    final offers =
        await (db.select(db.offers)..where(
              (t) =>
                  t.isDeleted.equals(false) &
                  t.status.equals('Active') &
                  t.startDate.isSmallerOrEqualValue(now) &
                  t.endDate.isBiggerOrEqualValue(now),
            ))
            .get();

    final models = <OfferModel>[];
    for (final offer in offers) {
      final items = await _getOfferItems(offer.id);
      models.add(_toModel(offer, items));
    }
    return models;
  }

  // Get all offers (including inactive/expired)
  Future<List<OfferModel>> getAllOffers() async {
    final offers = await (db.select(
      db.offers,
    )..where((t) => t.isDeleted.equals(false))).get();

    final models = <OfferModel>[];
    for (final offer in offers) {
      final items = await _getOfferItems(offer.id);
      models.add(_toModel(offer, items));
    }
    return models;
  }

  // Get single offer by ID
  Future<OfferModel?> getOfferById(int offerId) async {
    final offer = await (db.select(
      db.offers,
    )..where((t) => t.id.equals(offerId))).getSingleOrNull();
    if (offer == null) return null;

    final items = await _getOfferItems(offerId);
    return _toModel(offer, items);
  }

  // Get offer items for a specific offer
  Future<List<OfferItemModel>> _getOfferItems(int offerId) async {
    final items = await (db.select(
      db.offerItems,
    )..where((t) => t.offerId.equals(offerId))).get();
    final models = <OfferItemModel>[];

    for (final item in items) {
      final product = await (db.select(
        db.products,
      )..where((t) => t.id.equals(item.productId))).getSingleOrNull();
      models.add(
        OfferItemModel(
          id: item.id,
          offerId: item.offerId,
          productId: item.productId,
          discountPercent: item.discountPercent,
          discountedPrice: item.discountedPrice,
          quantity: item.quantity,
          createdAt: item.createdAt,
          productName: product?.name,
          originalPrice: product?.cashPrice,
        ),
      );
    }
    return models;
  }

  // Create new offer
  Future<int> createOffer({
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    required List<OfferItemModel> items,
    int? createdBy,
    bool isBundle = false,
  }) async {
    final offerId = await db
        .into(db.offers)
        .insert(
          OffersCompanion.insert(
            name: name,
            description: drift.Value(description),
            startDate: startDate,
            endDate: endDate,
            status: const drift.Value('Active'),
            createdBy: drift.Value(createdBy),
            isBundle: drift.Value(isBundle),
          ),
        );

    // Add items
    for (final item in items) {
      await db
          .into(db.offerItems)
          .insert(
            OfferItemsCompanion.insert(
              offerId: offerId,
              productId: item.productId,
              discountPercent: drift.Value(item.discountPercent),
              discountedPrice: item.discountedPrice,
              quantity: drift.Value(item.quantity),
            ),
          );
    }

    return offerId;
  }

  // Update offer
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
    await (db.update(db.offers)..where((t) => t.id.equals(offerId))).write(
      OffersCompanion(
        name: drift.Value(name),
        description: drift.Value(description),
        startDate: drift.Value(startDate),
        endDate: drift.Value(endDate),
        status: drift.Value(status),
        updatedAt: drift.Value(DateTime.now()),
        isBundle: drift.Value(isBundle),
      ),
    );

    // Delete existing items and add new ones
    await (db.delete(
      db.offerItems,
    )..where((t) => t.offerId.equals(offerId))).go();

    for (final item in items) {
      await db
          .into(db.offerItems)
          .insert(
            OfferItemsCompanion.insert(
              offerId: offerId,
              productId: item.productId,
              discountPercent: drift.Value(item.discountPercent),
              discountedPrice: item.discountedPrice,
              quantity: drift.Value(item.quantity),
            ),
          );
    }
  }

  // Delete offer (soft delete)
  Future<void> deleteOffer(int offerId) async {
    await (db.update(db.offers)..where((t) => t.id.equals(offerId))).write(
      const OffersCompanion(isDeleted: drift.Value(true)),
    );
  }

  // Get offer for a specific product
  Future<OfferItemModel?> getOfferForProduct(int productId) async {
    final now = DateTime.now();
    final offers =
        await (db.select(db.offers)..where(
              (t) =>
                  t.isDeleted.equals(false) &
                  t.status.equals('Active') &
                  t.startDate.isSmallerOrEqualValue(now) &
                  t.endDate.isBiggerOrEqualValue(now),
            ))
            .get();

    for (final offer in offers) {
      final item =
          await (db.select(db.offerItems)..where(
                (t) =>
                    t.offerId.equals(offer.id) & t.productId.equals(productId),
              ))
              .getSingleOrNull();
      if (item != null) {
        final product = await (db.select(
          db.products,
        )..where((t) => t.id.equals(productId))).getSingleOrNull();
        return OfferItemModel(
          id: item.id,
          offerId: item.offerId,
          productId: item.productId,
          discountPercent: item.discountPercent,
          discountedPrice: item.discountedPrice,
          quantity: item.quantity,
          createdAt: item.createdAt,
          productName: product?.name,
          originalPrice: product?.cashPrice,
        );
      }
    }
    return null;
  }

  OfferModel _toModel(Offer offer, List<OfferItemModel> items) {
    return OfferModel(
      id: offer.id,
      name: offer.name,
      description: offer.description,
      startDate: offer.startDate,
      endDate: offer.endDate,
      status: offer.status,
      createdAt: offer.createdAt,
      updatedAt: offer.updatedAt,
      createdBy: offer.createdBy,
      isDeleted: offer.isDeleted,
      isBundle: offer.isBundle,
      items: items,
    );
  }
}
