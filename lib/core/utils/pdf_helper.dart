import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/database/app_database.dart';

class PdfHelper {
  static Future<Uint8List> generateInvoicePdf(SalesInvoice invoice, Customer customer) async {
    // Load Arabic Font
    final fontData = await rootBundle.load('fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('شركة زمزم للفلاتر', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('فاتورة مبيعات', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('رقم الفاتورة: ${invoice.invoiceNumber}'),
                      pw.Text('التاريخ: ${invoice.date.toString().substring(0, 10)}'),
                      pw.Text('نوع الدفع: ${invoice.paymentType == 'CASH' ? 'كاش' : 'تقسيط'}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('العميل: ${customer.name}'),
                      pw.Text('رقم الهاتف: ${customer.phone1}'),
                      pw.Text('العنوان: ${customer.address ?? ''}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              // Items Table Placeholder (In a real app, query items from DB and pass them here)
              pw.Table.fromTextArray(
                headers: ['المنتج', 'الكمية', 'السعر', 'الإجمالي'],
                data: [
                  ['جهاز فلتر 7 مراحل', '1', '${invoice.totalAmount}', '${invoice.totalAmount}'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerRight,
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('الإجمالي الكلي: ${invoice.totalAmount} ج.م', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<pw.Font> getArabicFont() async {
    final fontData = await rootBundle.load('fonts/Cairo-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  static Future<void> printInvoice(SalesInvoice invoice, Customer customer) async {
    // Note: To prevent errors, we won't crash if the font is missing, but Cairo must be added to pubspec.
    try {
      final pdfBytes = await generateInvoicePdf(invoice, customer);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Invoice_${invoice.invoiceNumber}.pdf',
      );
    } catch (e) {
      print('Error printing PDF: $e');
    }
  }
}
