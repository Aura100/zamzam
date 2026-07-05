import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_provider.dart';
import '../domain/offer_model.dart';
import 'offers_providers.dart';

class AddEditOfferScreen extends ConsumerStatefulWidget {
  final int? offerId;

  const AddEditOfferScreen({super.key, this.offerId});

  @override
  ConsumerState<AddEditOfferScreen> createState() => _AddEditOfferScreenState();
}

class _AddEditOfferScreenState extends ConsumerState<AddEditOfferScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  DateTime? _startDate;
  DateTime? _endDate;
  List<OfferItemModel> _selectedItems = [];
  List<dynamic> _availableProducts = [];
  String _status = 'Active';
  bool _isBundle = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadProducts();
    if (widget.offerId != null) {
      _loadOffer();
    }
  }

  void _loadProducts() async {
    final db = ref.read(databaseProvider);
    final products =
        await (db.select(db.products)
              ..where((t) => t.isDeleted.equals(false))
              ..orderBy([(t) => drift.OrderingTerm(expression: t.name)]))
            .get();
    setState(() {
      _availableProducts = products;
    });
  }

  void _loadOffer() async {
    final repo = ref.read(offersRepositoryProvider);
    final offer = await repo.getOfferById(widget.offerId!);
    if (offer != null) {
      setState(() {
        _nameController.text = offer.name;
        _descriptionController.text = offer.description ?? '';
        _startDate = offer.startDate;
        _endDate = offer.endDate;
        _selectedItems = offer.items;
        _status = offer.status;
        _isBundle = offer.isBundle;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncValue = ref.watch(offersNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.offerId == null ? 'عرض جديد' : 'تعديل العرض'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offer Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم العرض *',
                hintText: 'مثال: عرض الصيف، تخفيف الجمعة السوداء',
                border: const OutlineInputBorder(),
                errorText:
                    _nameController.text.isEmpty &&
                        (asyncValue is AsyncValue ? false : true)
                    ? 'الاسم مطلوب'
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'الوصف',
                hintText: 'وصف تفصيلي للعرض',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Status
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Active', child: Text('نشط')),
                DropdownMenuItem(value: 'Inactive', child: Text('غير نشط')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Is Bundle
            SwitchListTile(
              title: const Text('عرض مجمع (Bundle)'),
              subtitle: const Text('يتطلب وجود جميع المنتجات المحددة في السلة لتطبيق العرض'),
              value: _isBundle,
              onChanged: (val) {
                setState(() => _isBundle = val);
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Start Date
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'تاريخ البداية *',
                      hintText: 'اختر تاريخ البداية',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _startDate != null ? _formatDate(_startDate!) : '',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // End Date
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'تاريخ النهاية *',
                      hintText: 'اختر تاريخ النهاية',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    controller: TextEditingController(
                      text: _endDate != null ? _formatDate(_endDate!) : '',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Products Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المنتجات (${_selectedItems.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddProductDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة منتج'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_selectedItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'لم تضف منتجات بعد',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _selectedItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        item.productName ?? 'منتج (${item.productId})',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السعر الأصلي: ${item.originalPrice?.toStringAsFixed(2) ?? 'N/A'} ج.م',
                          ),
                          Text(
                            'السعر المخفض: ${item.discountedPrice.toStringAsFixed(2)} ج.م',
                          ),
                          if (item.discountPercent != null)
                            Text(
                              'التخفيف: ${item.discountPercent?.toStringAsFixed(1)}%',
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _selectedItems.removeAt(index));
                        },
                      ),
                      onTap: () => _editProductOffer(index),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedItems.isEmpty ||
                        _startDate == null ||
                        _endDate == null ||
                        _nameController.text.isEmpty
                    ? null
                    : () => _saveOffer(),
                child: asyncValue.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حفظ العرض'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProductSelectionDialog(
        availableProducts: _availableProducts,
        onProductSelected: (product, discountPercent, discountedPrice) {
          final item = OfferItemModel(
            id: 0, // Temporary
            offerId: 0,
            productId: product.id,
            discountPercent: discountPercent,
            discountedPrice: discountedPrice,
            quantity: null,
            createdAt: DateTime.now(),
            productName: product.name,
            originalPrice: product.cashPrice,
          );

          setState(() {
            _selectedItems.add(item);
          });

          Navigator.pop(context);
        },
      ),
    );
  }

  void _editProductOffer(int index) {
    final item = _selectedItems[index];
    final discountController = TextEditingController(
      text: item.discountedPrice.toStringAsFixed(2),
    );
    final percentController = TextEditingController(
      text: item.discountPercent?.toStringAsFixed(1) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل سعر المنتج'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المنتج: ${item.productName}'),
            const SizedBox(height: 12),
            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر المخفض *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: percentController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'نسبة التخفيف %',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final newPrice = double.tryParse(discountController.text) ?? 0;
              final newPercent = double.tryParse(percentController.text);

              setState(() {
                _selectedItems[index] = item.copyWith(
                  discountedPrice: newPrice,
                  discountPercent: newPercent,
                );
              });

              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOffer() async {
    if (_nameController.text.isEmpty ||
        _startDate == null ||
        _endDate == null ||
        _selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    try {
      final notifier = ref.read(offersNotifierProvider.notifier);

      if (widget.offerId == null) {
        await notifier.createOffer(
          name: _nameController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          startDate: _startDate!,
          endDate: _endDate!,
          items: _selectedItems,
          isBundle: _isBundle,
        );
      } else {
        await notifier.updateOffer(
          offerId: widget.offerId!,
          name: _nameController.text,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          startDate: _startDate!,
          endDate: _endDate!,
          status: _status,
          items: _selectedItems,
          isBundle: _isBundle,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.offerId == null
                ? 'تم إنشاء العرض بنجاح'
                : 'تم تحديث العرض بنجاح',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ProductSelectionDialog extends StatefulWidget {
  final List<dynamic> availableProducts;
  final Function(
    dynamic product,
    double? discountPercent,
    double discountedPrice,
  )
  onProductSelected;

  const _ProductSelectionDialog({
    required this.availableProducts,
    required this.onProductSelected,
  });

  @override
  State<_ProductSelectionDialog> createState() =>
      _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  dynamic _selectedProduct;
  final _discountController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختر منتج'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<dynamic>(
              isExpanded: true,
              hint: const Text('اختر المنتج'),
              value: _selectedProduct,
              items: widget.availableProducts
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProduct = value;
                  _priceController.text = (value?.cashPrice ?? 0)
                      .toStringAsFixed(2);
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedProduct != null) ...[
              TextField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'السعر الأصلي',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(
                  text: (_selectedProduct.cashPrice).toStringAsFixed(2),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'نسبة التخفيف % (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر المخفض *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _selectedProduct == null
              ? null
              : () {
                  final discountPrice =
                      double.tryParse(_priceController.text) ?? 0;
                  final discountPercent = double.tryParse(
                    _discountController.text,
                  );

                  widget.onProductSelected(
                    _selectedProduct,
                    discountPercent,
                    discountPrice,
                  );
                },
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _discountController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
