import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';

class CartItem {
  final Product product;
  int quantity;
  double get total =>
      product.cashPrice * quantity; // Defaults to cash price initially

  CartItem({required this.product, this.quantity = 1});
}

final cartProvider = StateProvider<List<CartItem>>((ref) => []);
final selectedCustomerProvider = StateProvider<Customer?>((ref) => null);
final paymentTypeProvider = StateProvider<String>(
  (ref) => 'CASH',
); // CASH or INSTALLMENT
final discountProvider = StateProvider<double>((ref) => 0.0);
final feesProvider = StateProvider<double>((ref) => 0.0);
final applyOffersProvider = StateProvider<bool>((ref) => false);

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  final paymentType = ref.watch(paymentTypeProvider);

  double total = 0.0;
  for (var item in cart) {
    total +=
        (paymentType == 'CASH'
            ? item.product.cashPrice
            : item.product.installmentPrice) *
        item.quantity;
  }

  final discount = ref.watch(discountProvider);
  final fees = ref.watch(feesProvider);

  return total - discount + fees;
});
