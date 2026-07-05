import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import 'products_providers.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;
  final int productType; // 0 = New, 1 = Used

  const AddProductScreen({
    super.key, 
    this.productToEdit,
    this.productType = 0,
  });

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Filters');
  final _cashPriceController = TextEditingController();
  final _installmentPriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      _nameController.text = widget.productToEdit!.name;
      _categoryController.text = widget.productToEdit!.category;
      _cashPriceController.text = widget.productToEdit!.cashPrice.toString();
      _installmentPriceController.text = widget.productToEdit!.installmentPrice.toString();
      _purchasePriceController.text = widget.productToEdit!.purchasePrice?.toString() ?? '';
      _stockController.text = widget.productToEdit!.currentStock.toString();
      _barcodeController.text = widget.productToEdit!.barcode ?? '';
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      if (widget.productToEdit != null) {
        final updatedProduct = widget.productToEdit!.copyWith(
          name: _nameController.text,
          category: _categoryController.text,
          cashPrice: double.tryParse(_cashPriceController.text) ?? 0.0,
          installmentPrice: double.tryParse(_installmentPriceController.text) ?? 0.0,
          purchasePrice: double.tryParse(_purchasePriceController.text) ?? 0.0,
          currentStock: int.tryParse(_stockController.text) ?? 0,
          barcode: drift.Value(_barcodeController.text.isEmpty ? null : _barcodeController.text),
        );
        await ref.read(productsRepositoryProvider).updateProduct(updatedProduct);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث المنتج بنجاح'), backgroundColor: Colors.green),
          );
          context.pop();
        }
      } else {
        final product = ProductsCompanion(
          name: drift.Value(_nameController.text),
          category: drift.Value(_categoryController.text),
          cashPrice: drift.Value(double.tryParse(_cashPriceController.text) ?? 0.0),
          installmentPrice: drift.Value(double.tryParse(_installmentPriceController.text) ?? 0.0),
          purchasePrice: drift.Value(double.tryParse(_purchasePriceController.text) ?? 0.0),
          currentStock: drift.Value(int.tryParse(_stockController.text) ?? 0),
          productType: drift.Value(widget.productType),
          barcode: drift.Value(_barcodeController.text.isEmpty ? null : _barcodeController.text),
        );

        await ref.read(productsRepositoryProvider).addProduct(product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة المنتج بنجاح'), backgroundColor: Colors.green),
          );
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: widget.productToEdit != null ? 'تعديل بيانات المنتج' : 'إضافة منتج جديد',
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بيانات المنتج', style: Theme.of(context).textTheme.headlineSmall),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'اسم المنتج',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _categoryController.text,
                              decoration: const InputDecoration(
                                labelText: 'الفئة',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Filters', child: Text('فلاتر')),
                                DropdownMenuItem(value: 'Candles', child: Text('شمعات')),
                                DropdownMenuItem(value: 'Pumps', child: Text('مواتير')),
                                DropdownMenuItem(value: 'Tanks', child: Text('خزانات')),
                                DropdownMenuItem(value: 'Accessories', child: Text('إكسسوارات')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _categoryController.text = val;
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cashPriceController,
                              decoration: const InputDecoration(
                                labelText: 'سعر البيع (كاش)',
                                border: OutlineInputBorder(),
                                suffixText: 'ج.م',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _installmentPriceController,
                              decoration: const InputDecoration(
                                labelText: 'سعر البيع (قسط)',
                                border: OutlineInputBorder(),
                                suffixText: 'ج.م',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceController,
                              decoration: const InputDecoration(
                                labelText: 'سعر الشراء (التكلفة)',
                                border: OutlineInputBorder(),
                                suffixText: 'ج.م',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              decoration: const InputDecoration(
                                labelText: 'المخزون الافتتاحي',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'الباركود (اختياري)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.qr_code_scanner),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('إلغاء'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _saveProduct,
                            icon: const Icon(Icons.save),
                            label: Text(widget.productToEdit != null ? 'تحديث البيانات' : 'حفظ المنتج'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
