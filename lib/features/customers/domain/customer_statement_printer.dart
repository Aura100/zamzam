import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Generates and prints a comprehensive A4 customer account statement PDF.
/// Shows: customer info, sales invoices, installment payments, maintenance history,
/// and a running balance summary.
class CustomerStatementPrinter {
  final AppDatabase _db;

  CustomerStatementPrinter(this._db);

  /// Fetches all financial data for a customer and generates a PDF statement.
  Future<void> printStatement(Customer customer) async {
    // Fetch all related data
    final invoices = await (_db.select(_db.salesInvoices)
          ..where((t) => t.customerId.equals(customer.id))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .get();

    final contracts = await (_db.select(_db.installmentContracts)
          ..where((t) => t.customerId.equals(customer.id)))
        .get();

    final List<Installment> allInstallments = [];
    for (final contract in contracts) {
      final installments = await (_db.select(_db.installments)
            ..where((t) => t.contractId.equals(contract.id))
            ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
          .get();
      allInstallments.addAll(installments);
    }

    final maintenanceRequests = await (_db.select(_db.maintenanceRequests)
          ..where((t) => t.customerId.equals(customer.id))
          ..orderBy([(t) => OrderingTerm(expression: t.scheduledDate, mode: OrderingMode.desc)]))
        .get();

    // Build PDF
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();

    // Calculate summary
    final totalInvoicesAmount = invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final totalPaid = allInstallments
        .where((i) => i.status == 'Paid')
        .fold(0.0, (sum, i) => sum + i.amount);
    final totalPartialPaid = allInstallments.fold(0.0, (sum, i) => sum + i.partialPaidAmount);
    final cashInvoicesTotal = invoices
        .where((inv) => inv.paymentType == 'CASH')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final installmentInvoicesTotal = invoices
        .where((inv) => inv.paymentType == 'INSTALLMENT')
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final totalMaintenanceCost = maintenanceRequests.fold(0.0, (sum, m) => sum + m.cost);
    final totalPayments = totalPartialPaid + cashInvoicesTotal;
    final remainingBalance = installmentInvoicesTotal - totalPartialPaid;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('شركة زمزم للفلاتر',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('كشف حساب عميل',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 2, color: PdfColors.blue800),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('تاريخ الطباعة: ${dateFormatter.format(now)}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        build: (pw.Context context) => [
          // Customer Info Section
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('الاسم: ${customer.name}',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('رقم الهاتف: ${customer.phone1}', style: const pw.TextStyle(fontSize: 11)),
                    if (customer.phone2 != null && customer.phone2!.isNotEmpty)
                      pw.Text('هاتف 2: ${customer.phone2}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('العنوان: ${customer.address ?? 'غير محدد'}', style: const pw.TextStyle(fontSize: 11)),
                    if (customer.governorate != null)
                      pw.Text('المحافظة: ${customer.governorate}', style: const pw.TextStyle(fontSize: 11)),
                    if (customer.area != null)
                      pw.Text('المنطقة: ${customer.area}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Financial Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ملخص مالي',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryItem('إجمالي الفواتير', '${totalInvoicesAmount.toStringAsFixed(2)} ج.م', arabicFont),
                    _summaryItem('مبيعات كاش', '${cashInvoicesTotal.toStringAsFixed(2)} ج.م', arabicFont),
                    _summaryItem('مبيعات تقسيط', '${installmentInvoicesTotal.toStringAsFixed(2)} ج.م', arabicFont),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryItem('إجمالي المدفوعات', '${totalPayments.toStringAsFixed(2)} ج.م', arabicFont),
                    _summaryItem('المتبقي على العميل', '${remainingBalance.toStringAsFixed(2)} ج.م', arabicFont,
                        color: remainingBalance > 0 ? PdfColors.red : PdfColors.green700),
                    _summaryItem('تكاليف صيانة', '${totalMaintenanceCost.toStringAsFixed(2)} ج.م', arabicFont),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Sales Invoices Table
          if (invoices.isNotEmpty) ...[
            pw.Text('فواتير المبيعات',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['رقم الفاتورة', 'التاريخ', 'نوع الدفع', 'الإجمالي'],
              data: invoices
                  .map((inv) => [
                        inv.invoiceNumber,
                        dateFormatter.format(inv.date),
                        inv.paymentType == 'CASH' ? 'كاش' : 'تقسيط',
                        '${inv.totalAmount.toStringAsFixed(2)} ج.م',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 20),
          ],

          // Installment Payments Table
          if (allInstallments.isNotEmpty) ...[
            pw.Text('سجل الأقساط',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['رقم العقد', 'تاريخ الاستحقاق', 'المبلغ', 'المدفوع', 'الحالة'],
              data: allInstallments
                  .map((inst) => [
                        '${inst.contractId}',
                        dateFormatter.format(inst.dueDate),
                        '${inst.amount.toStringAsFixed(2)} ج.م',
                        '${inst.partialPaidAmount.toStringAsFixed(2)} ج.م',
                        inst.status == 'Paid'
                            ? 'مدفوع'
                            : inst.status == 'Late'
                                ? 'متأخر'
                                : 'قيد الانتظار',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green100),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 20),
          ],

          // Maintenance History Table
          if (maintenanceRequests.isNotEmpty) ...[
            pw.Text('سجل الصيانة',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ', 'الوصف', 'الحالة', 'التكلفة'],
              data: maintenanceRequests
                  .map((m) => [
                        dateFormatter.format(m.scheduledDate),
                        m.issueDescription,
                        m.status == 'Completed'
                            ? 'مكتمل'
                            : m.status == 'InProgress'
                                ? 'جاري'
                                : 'معلق',
                        '${m.cost.toStringAsFixed(2)} ج.م',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange100),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_${customer.name}_${dateFormatter.format(now)}.pdf',
    );
  }

  pw.Widget _summaryItem(String label, String value, pw.Font font, {PdfColor? color}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: color ?? PdfColors.black)),
      ],
    );
  }
}
