import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import '../../products/presentation/products_providers.dart';
import 'customers_providers.dart';

class LegacyCustomerScreen extends ConsumerStatefulWidget {
  const LegacyCustomerScreen({super.key});

  @override
  ConsumerState<LegacyCustomerScreen> createState() => _LegacyCustomerScreenState();
}

class _LegacyCustomerScreenState extends ConsumerState<LegacyCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _debtController = TextEditingController(text: '0');
  
  Product? _selectedProduct;
  DateTime _purchaseDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _lastMaintenanceDate = DateTime.now().subtract(const Duration(days: 90));
  int _cycleMonths = 3;

  @override
  void dispose() {
    _nameController.dispose();
    _phone1Controller.dispose();
    _addressController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isPurchase) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPurchase ? _purchaseDate : _lastMaintenanceDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = picked;
          // Auto adjust last maintenance if purchase date is newer
          if (_purchaseDate.isAfter(_lastMaintenanceDate)) {
            _lastMaintenanceDate = _purchaseDate;
          }
        } else {
          _lastMaintenanceDate = picked;
        }
      });
    }
  }

  Future<void> _saveLegacyCustomer() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار المنتج'), backgroundColor: Colors.red),
        );
        return;
      }

      final debt = double.tryParse(_debtController.text) ?? 0.0;
      final customer = CustomersCompanion.insert(
        name: _nameController.text,
        phone1: _phone1Controller.text,
        address: drift.Value(_addressController.text),
      );

      await ref.read(customersRepositoryProvider).addLegacyCustomer(
        customer: customer,
        productId: _selectedProduct!.id,
        purchaseDate: _purchaseDate,
        lastMaintenanceDate: _lastMaintenanceDate,
        cycleMonths: _cycleMonths,
        remainingDebt: debt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إضافة العميل القديم وجدول صيانته بنجاح'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return AppLayout(
      title: 'إضافة عميل سابق (إدخال سريع)',
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
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
                      Text('البيانات الشخصية', style: Theme.of(context).textTheme.headlineSmall),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'اسم العميل رباعي', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _phone1Controller,
                              decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'العنوان بالتفصيل', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 32),

                      Text('بيانات الفلتر والصيانة السابقة', style: Theme.of(context).textTheme.headlineSmall),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: productsAsync.when(
                              loading: () => const CircularProgressIndicator(),
                              error: (err, stack) => const Text('خطأ في تحميل المنتجات'),
                              data: (products) {
                                return DropdownButtonFormField<Product>(
                                  decoration: const InputDecoration(labelText: 'اختر الفلتر / المنتج', border: OutlineInputBorder()),
                                  value: _selectedProduct,
                                  items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                                  onChanged: (val) => setState(() => _selectedProduct = val),
                                );
                              }
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              decoration: const InputDecoration(labelText: 'دورة الصيانة (بالأشهر)', border: OutlineInputBorder()),
                              value: _cycleMonths,
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('كل شهر')),
                                DropdownMenuItem(value: 2, child: Text('كل شهرين')),
                                DropdownMenuItem(value: 3, child: Text('كل 3 أشهر')),
                                DropdownMenuItem(value: 6, child: Text('كل 6 أشهر')),
                                DropdownMenuItem(value: 12, child: Text('كل سنة')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _cycleMonths = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, true),
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'تاريخ الشراء الأصلي', border: OutlineInputBorder()),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(dateFormat.format(_purchaseDate)),
                                    const Icon(Icons.calendar_today),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'تاريخ آخر صيانة تمت', border: OutlineInputBorder()),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(dateFormat.format(_lastMaintenanceDate)),
                                    const Icon(Icons.calendar_today),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Text('الحسابات والديون السابقة (إن وجدت)', style: Theme.of(context).textTheme.headlineSmall),
                      const Divider(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _debtController,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ المتبقي على العميل (ديون سابقة)',
                          border: OutlineInputBorder(),
                          suffixText: 'ج.م',
                        ),
                        keyboardType: TextInputType.number,
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
                            onPressed: _saveLegacyCustomer,
                            icon: const Icon(Icons.save),
                            label: const Text('حفظ عميل سابق'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
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
