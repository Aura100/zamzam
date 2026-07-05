import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import 'customers_providers.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final Customer? customerToEdit;
  const AddCustomerScreen({super.key, this.customerToEdit});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _addressController = TextEditingController();
  final _nationalIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.customerToEdit != null) {
      _nameController.text = widget.customerToEdit!.name;
      _phone1Controller.text = widget.customerToEdit!.phone1;
      _addressController.text = widget.customerToEdit!.address ?? '';
      _nationalIdController.text = widget.customerToEdit!.nationalId ?? '';
    }
  }

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      if (widget.customerToEdit != null) {
        final updatedCustomer = widget.customerToEdit!.copyWith(
          name: _nameController.text,
          phone1: _phone1Controller.text,
          address: drift.Value(_addressController.text.isNotEmpty ? _addressController.text : null),
          nationalId: drift.Value(_nationalIdController.text.isNotEmpty ? _nationalIdController.text : null),
        );
        await ref.read(customersRepositoryProvider).updateCustomer(updatedCustomer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث العميل بنجاح'), backgroundColor: Colors.green),
          );
          context.pop();
        }
      } else {
        final customer = CustomersCompanion(
          name: drift.Value(_nameController.text),
          phone1: drift.Value(_phone1Controller.text),
          address: drift.Value(_addressController.text),
          nationalId: drift.Value(_nationalIdController.text),
        );

        await ref.read(customersRepositoryProvider).addCustomer(customer);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة العميل بنجاح'), backgroundColor: Colors.green),
          );
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: widget.customerToEdit != null ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
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
                      Text('بيانات العميل', style: Theme.of(context).textTheme.headlineSmall),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'اسم العميل رباعي',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _phone1Controller,
                              decoration: const InputDecoration(
                                labelText: 'رقم الهاتف (أساسي)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nationalIdController,
                              decoration: const InputDecoration(
                                labelText: 'الرقم القومي (14 رقم)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'العنوان بالتفصيل',
                                border: OutlineInputBorder(),
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
                            onPressed: _saveCustomer,
                            icon: const Icon(Icons.save),
                            label: Text(widget.customerToEdit != null ? 'تحديث البيانات' : 'حفظ العميل'),
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
