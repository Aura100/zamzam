import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import 'pos_state.dart';
import 'sales_providers.dart';

class InstallmentWizardScreen extends ConsumerStatefulWidget {
  final double totalAmount;
  final int customerId;

  const InstallmentWizardScreen({
    super.key,
    required this.totalAmount,
    required this.customerId,
  });

  @override
  ConsumerState<InstallmentWizardScreen> createState() => _InstallmentWizardScreenState();
}

class _InstallmentWizardScreenState extends ConsumerState<InstallmentWizardScreen> {
  final _downPaymentController = TextEditingController();
  final _monthsController = TextEditingController(text: '12');
  
  double get downPayment => double.tryParse(_downPaymentController.text) ?? 0.0;
  int get months => int.tryParse(_monthsController.text) ?? 12;
  
  double get remainingAmount => widget.totalAmount - downPayment;
  double get monthlyAmount => months > 0 ? remainingAmount / months : 0;

  Future<void> _submit() async {
    if (months <= 0) return;
    
    final cart = ref.read(cartProvider);
    final invoice = SalesInvoicesCompanion.insert(
      invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      customerId: widget.customerId,
      paymentType: 'INSTALLMENT',
      totalAmount: widget.totalAmount,
    );
    
    final items = cart.map((i) => InvoiceItemsCompanion.insert(
      invoiceId: 0, 
      productId: i.product.id,
      quantity: i.quantity,
      unitPrice: i.product.installmentPrice,
    )).toList();

    final startDate = DateTime.now();
    final contract = InstallmentContractsCompanion.insert(
      contractNumber: 'CON-${DateTime.now().millisecondsSinceEpoch}',
      invoiceId: 0,
      customerId: widget.customerId,
      downPayment: downPayment,
      remainingBalance: remainingAmount,
      months: months,
      monthlyAmount: monthlyAmount,
      startDate: startDate,
      nextDueDate: drift.Value(DateTime(startDate.year, startDate.month + 1, startDate.day)),
    );

    List<InstallmentsCompanion> installments = [];
    for (int i = 1; i <= months; i++) {
      installments.add(InstallmentsCompanion.insert(
        contractId: 0,
        dueDate: DateTime(startDate.year, startDate.month + i, startDate.day),
        amount: monthlyAmount,
      ));
    }

    await ref.read(salesRepositoryProvider).createInstallmentSale(
      invoice: invoice,
      items: items,
      contract: contract,
      installments: installments,
    );

    ref.read(cartProvider.notifier).state = [];
    ref.read(selectedCustomerProvider.notifier).state = null;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء عقد التقسيط بنجاح'), backgroundColor: Colors.green));
      context.pop(); // close dialog
      context.pop(); // close pos screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعداد عقد التقسيط'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إجمالي الفاتورة: ${widget.totalAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _downPaymentController,
              decoration: const InputDecoration(labelText: 'المقدم', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _monthsController,
              decoration: const InputDecoration(labelText: 'عدد الأشهر', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المتبقي:'),
                Text('${remainingAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('القسط الشهري:'),
                Text('${monthlyAmount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _submit, child: const Text('تأكيد العقد')),
      ],
    );
  }
}
