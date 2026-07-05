import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/sales_repository.dart';
import 'pos_state.dart';
import '../../offers/domain/offer_model.dart';
import '../../offers/presentation/offers_providers.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SalesRepository(db);
});

final invoicesStreamProvider = StreamProvider<List<SalesInvoice>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return repository.watchAllInvoices();
});

final salesReturnsStreamProvider = StreamProvider<List<SalesReturn>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.salesReturns)..orderBy([
        (t) => drift.OrderingTerm(
          expression: t.returnDate,
          mode: drift.OrderingMode.desc,
        ),
      ]))
      .watch();
});

// Provider to determine if a specific product in the cart gets an offer
final appliedOfferForItemProvider = FutureProvider.family<OfferItemModel?, int>((ref, productId) async {
  final applyOffers = ref.watch(applyOffersProvider);
  if (!applyOffers) return null;

  final offersRepo = ref.watch(offersRepositoryProvider);
  final activeOffers = await offersRepo.getActiveOffers();
  final cart = ref.watch(cartProvider);
  final cartProductIds = cart.map((i) => i.product.id).toSet();

  for (final offer in activeOffers) {
    if (offer.isBundle) {
      final offerProductIds = offer.items.map((i) => i.productId).toSet();
      // If the cart does not contain all products in the bundle, this offer is invalid
      if (!offerProductIds.every((id) => cartProductIds.contains(id))) {
        continue; 
      }
    }
    
    // Check if this offer includes our product
    final item = offer.items.where((i) => i.productId == productId).firstOrNull;
    if (item != null) return item;
  }
  
  return null;
});

// Calculate total with offers consideration
final cartTotalWithOffersProvider = FutureProvider<double>((ref) async {
  final cart = ref.watch(cartProvider);
  final paymentType = ref.watch(paymentTypeProvider);

  double total = 0.0;

  for (var item in cart) {
    // Check if product has an active offer that applies to it
    final offerItem = await ref.watch(appliedOfferForItemProvider(item.product.id).future);

    if (offerItem != null) {
      // Use offer price
      total += offerItem.discountedPrice * item.quantity;
    } else {
      // Use regular price based on payment type
      total +=
          (paymentType == 'CASH'
              ? item.product.cashPrice
              : item.product.installmentPrice) *
          item.quantity;
    }
  }

  final discount = ref.watch(discountProvider);
  final fees = ref.watch(feesProvider);

  return total - discount + fees;
});
