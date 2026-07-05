import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../customers/presentation/customers_providers.dart';
import '../../products/presentation/products_providers.dart';
import 'sales_providers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'pos_state.dart';
import 'installment_wizard_screen.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _barcodeCtrl = TextEditingController();
  final _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onBarcodeSubmitted(String value) {
    if (value.trim().isEmpty) return;

    final products = ref.read(productsStreamProvider).valueOrNull ?? [];
    final match = products
        .where(
          (p) =>
              p.name.contains(value) ||
              p.id.toString() == value ||
              p.barcode == value,
        )
        .firstOrNull;

    if (match != null) {
      final currentCart = ref.read(cartProvider);
      final existingIndex = currentCart.indexWhere(
        (i) => i.product.id == match.id,
      );
      if (existingIndex >= 0) {
        currentCart[existingIndex].quantity++;
        ref.read(cartProvider.notifier).state = [...currentCart];
      } else {
        ref.read(cartProvider.notifier).state = [
          ...currentCart,
          CartItem(product: match),
        ];
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة ${match.name}'),
          duration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('المنتج غير موجود'),
          backgroundColor: Colors.red,
        ),
      );
    }

    _barcodeCtrl.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);
    final cart = ref.watch(cartProvider);
    final selectedCustomer = ref.watch(selectedCustomerProvider);
    final paymentType = ref.watch(paymentTypeProvider);
    final totalAsync = ref.watch(cartTotalWithOffersProvider);

    return AppLayout(
      title: 'إنشاء فاتورة مبيعات (POS)',
      child: Row(
        children: [
          // Products Area
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeCtrl,
                          focusNode: _focusNode,
                          autofocus: true,
                          onSubmitted: _onBarcodeSubmitted,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'البحث عن منتج (باركود / اسم)...',
                            prefixIcon: const Icon(Icons.qr_code_scanner),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.blue,
                          size: 32,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('مسح الباركود بالكاميرا'),
                              content: SizedBox(
                                width: 300,
                                height: 300,
                                child: MobileScanner(
                                  onDetect: (capture) {
                                    final List<Barcode> barcodes =
                                        capture.barcodes;
                                    if (barcodes.isNotEmpty &&
                                        barcodes.first.rawValue != null) {
                                      Navigator.pop(ctx);
                                      _barcodeCtrl.text =
                                          barcodes.first.rawValue!;
                                      _onBarcodeSubmitted(
                                        barcodes.first.rawValue!,
                                      );
                                    }
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('إلغاء'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: productsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('خطأ: $err')),
                      data: (products) {
                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: products
                              .where(
                                (p) =>
                                    p.name.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    p.id.toString().contains(_searchQuery) ||
                                    (p.barcode?.toLowerCase().contains(
                                          _searchQuery,
                                        ) ??
                                        false),
                              )
                              .length,
                          itemBuilder: (context, index) {
                            final allProducts = products
                                .where(
                                  (p) =>
                                      p.name.toLowerCase().contains(
                                        _searchQuery,
                                      ) ||
                                      p.id.toString().contains(_searchQuery) ||
                                      (p.barcode?.toLowerCase().contains(
                                            _searchQuery,
                                          ) ??
                                          false),
                                )
                                .toList();
                            if (index >= allProducts.length)
                              return const SizedBox.shrink();
                            final product = allProducts[index];
                            return InkWell(
                              onTap: () {
                                final currentCart = ref.read(cartProvider);
                                final existingIndex = currentCart.indexWhere(
                                  (i) => i.product.id == product.id,
                                );
                                if (existingIndex >= 0) {
                                  currentCart[existingIndex].quantity++;
                                  ref.read(cartProvider.notifier).state = [
                                    ...currentCart,
                                  ];
                                } else {
                                  ref.read(cartProvider.notifier).state = [
                                    ...currentCart,
                                    CartItem(product: product),
                                  ];
                                }
                              },
                              child: Card(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.inventory_2,
                                      size: 48,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      product.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('كاش: ${product.cashPrice} ج.م'),
                                    Text(
                                      'قسط: ${product.installmentPrice} ج.م',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cart Area
          Container(
            width: 350,
            color: Colors.white,
            child: Column(
              children: [
                // Customer Selection
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: customersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, stack) => const Text('خطأ في تحميل العملاء'),
                    data: (customers) {
                      return DropdownButtonFormField<Customer>(
                        decoration: const InputDecoration(
                          labelText: 'اختر العميل',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedCustomer,
                        items: customers
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          ref.read(selectedCustomerProvider.notifier).state =
                              val;
                        },
                      );
                    },
                  ),
                ),

                // Payment Type
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('كاش'),
                          value: 'CASH',
                          groupValue: paymentType,
                          onChanged: (val) =>
                              ref.read(paymentTypeProvider.notifier).state =
                                  val!,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('قسط'),
                          value: 'INSTALLMENT',
                          groupValue: paymentType,
                          onChanged: (val) =>
                              ref.read(paymentTypeProvider.notifier).state =
                                  val!,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Apply Offers Toggle
                Consumer(
                  builder: (context, ref, child) {
                    final applyOffers = ref.watch(applyOffersProvider);
                    return SwitchListTile(
                      title: const Text('تفعيل العروض'),
                      subtitle: const Text('تطبيق العروض المتاحة (فردية ومجمعة)'),
                      value: applyOffers,
                      onChanged: (val) {
                        ref.read(applyOffersProvider.notifier).state = val;
                      },
                    );
                  },
                ),
                const Divider(),

                // Cart Items
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final price = paymentType == 'CASH'
                          ? item.product.cashPrice
                          : item.product.installmentPrice;

                      return Column(
                        children: [
                          ListTile(
                            title: Text(item.product.name),
                            subtitle: Text('${price} ج.م x ${item.quantity}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    final current = ref.read(cartProvider);
                                    if (current[index].quantity > 1) {
                                      current[index].quantity--;
                                    } else {
                                      current.removeAt(index);
                                    }
                                    ref.read(cartProvider.notifier).state = [
                                      ...current,
                                    ];
                                  },
                                ),
                                Text('${price * item.quantity} ج.م'),
                              ],
                            ),
                          ),
                          // Show active offer if exists
                          Consumer(
                            builder: (context, ref, child) {
                              final offerItemAsync = ref.watch(
                                appliedOfferForItemProvider(item.product.id),
                              );
                              return offerItemAsync.when(
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (offerItem) {
                                  if (offerItem != null) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 4.0,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          border: Border.all(
                                            color: Colors.green,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'عرض نشط',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  '${price.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                    color: Colors.grey,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${offerItem.discountedPrice.toStringAsFixed(2)} ج.م',
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(),

                // Totals
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      totalAsync.when(
                        loading: () => const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الإجمالي',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            CircularProgressIndicator(),
                          ],
                        ),
                        error: (_, __) => const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الإجمالي',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('خطأ في الحساب'),
                          ],
                        ),
                        data: (total) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'الإجمالي',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$total ج.م',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (cart.isEmpty || selectedCustomer == null)
                              ? null
                              : () async {
                                  final total = totalAsync.valueOrNull ?? 0.0;
                                  if (paymentType == 'INSTALLMENT') {
                                    // Open Installment Wizard
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => InstallmentWizardScreen(
                                        totalAmount: total,
                                        customerId: selectedCustomer.id,
                                      ),
                                    );
                                  } else {
                                    // Process Cash Sale
                                    final invoice = SalesInvoicesCompanion.insert(
                                      invoiceNumber:
                                          'INV-${DateTime.now().millisecondsSinceEpoch}',
                                      customerId: selectedCustomer.id,
                                      paymentType: 'CASH',
                                      totalAmount: total,
                                    );

                                    final items = cart
                                        .map(
                                          (i) => InvoiceItemsCompanion.insert(
                                            invoiceId: 0, // Handled by repo
                                            productId: i.product.id,
                                            quantity: i.quantity,
                                            unitPrice: paymentType == 'CASH'
                                                ? i.product.cashPrice
                                                : i.product.installmentPrice,
                                          ),
                                        )
                                        .toList();

                                    await ref
                                        .read(salesRepositoryProvider)
                                        .createCashSale(
                                          invoice: invoice,
                                          items: items,
                                        );

                                    // Clear and pop
                                    ref.read(cartProvider.notifier).state = [];
                                    ref
                                            .read(
                                              selectedCustomerProvider.notifier,
                                            )
                                            .state =
                                        null;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'تم تسجيل المبيعات بنجاح',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      context.pop();
                                    }
                                  }
                                },
                          child: Text(
                            paymentType == 'CASH'
                                ? 'دفع كاش'
                                : 'التوجه للتقسيط',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
