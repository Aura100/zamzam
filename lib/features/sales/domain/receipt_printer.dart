import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/app_database.dart';
import 'package:intl/intl.dart';

class ReceiptPrinter {
  // Brand colors for a highly professional look
  static const _primaryColor = PdfColor.fromInt(0xFF0F3460); // Deep Blue/Navy
  static const _accentColor = PdfColor.fromInt(0xFF16213E);  // Darker Blue
  static const _lightBg = PdfColor.fromInt(0xFFF9FAFC);
  static const _borderColor = PdfColor.fromInt(0xFFE2E8F0);
  static const _textDark = PdfColor.fromInt(0xFF1A202C);
  static const _textMuted = PdfColor.fromInt(0xFF718096);
  static const _successGreen = PdfColor.fromInt(0xFF38A169);
  static const _warningOrange = PdfColor.fromInt(0xFFDD6B20);

  static Future<void> printInvoice(
    SalesInvoice invoice,
    String customerName,
    List<InvoiceItem> items, {
    String customerPhone = '',
    String customerAddress = '',
    List<String> productNames = const [],
    String companyName = 'شركة زمزم للفلاتر',
    String companyPhone = '01000000000',
    String companyAddress = 'القاهرة، مصر',
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final dateFormat = DateFormat('yyyy/MM/dd');
    final currencyFormat = NumberFormat('#,##0.00');

    // Build items rows
    final itemRows = <pw.TableRow>[];

    // Header row
    itemRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: _primaryColor,
        borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6)),
      ),
      children: [
        _headerCell('الإجمالي', arabicBold),
        _headerCell('سعر الوحدة', arabicBold),
        _headerCell('الكمية', arabicBold),
        _headerCell('المنتج / الخدمة', arabicBold),
        _headerCell('#', arabicBold),
      ],
    ));

    // Data rows
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final productName = (i < productNames.length && productNames[i].isNotEmpty)
          ? productNames[i]
          : 'منتج ${item.productId}';
      final total = item.unitPrice * item.quantity;
      final isEven = i % 2 == 0;

      itemRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(
          color: isEven ? _lightBg : PdfColors.white,
          border: const pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.5)),
        ),
        children: [
          _dataCell('${currencyFormat.format(total)}', arabicFont, bold: true),
          _dataCell('${currencyFormat.format(item.unitPrice)}', arabicFont),
          _dataCell('${item.quantity}', arabicFont, center: true),
          _dataCell(productName, arabicFont),
          _dataCell('${i + 1}', arabicFont, center: true, muted: true),
        ],
      ));
    }

    final isCash = invoice.paymentType == 'CASH' || invoice.paymentType == 'نقدي';
    final paymentLabel = isCash ? 'نقداً' : 'تقسيط';
    final paymentColor = isCash ? _successGreen : _warningOrange;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── HEADER ────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company Info (Right)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(font: arabicBold, fontSize: 26, color: _primaryColor),
                      ),
                      pw.SizedBox(height: 4),
                      if (companyPhone.isNotEmpty)
                        pw.Text('هاتف: $companyPhone', style: pw.TextStyle(font: arabicFont, fontSize: 11, color: _textMuted)),
                      if (companyAddress.isNotEmpty)
                        pw.Text('العنوان: $companyAddress', style: pw.TextStyle(font: arabicFont, fontSize: 11, color: _textMuted)),
                    ],
                  ),
                  // Invoice Badge (Left)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: pw.BoxDecoration(
                          color: _primaryColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          'فـاتـورة مـبـيـعـات',
                          style: pw.TextStyle(font: arabicBold, fontSize: 16, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '#INV-${invoice.invoiceNumber}',
                        style: pw.TextStyle(font: arabicBold, fontSize: 14, color: _textDark),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'التاريخ: ${dateFormat.format(invoice.date)}',
                        style: pw.TextStyle(font: arabicFont, fontSize: 11, color: _textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),

              // ── INFO CARDS ROW ─────────────────────────────────────────────
              pw.Row(
                children: [
                  // Customer Info
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _borderColor),
                        borderRadius: pw.BorderRadius.circular(8),
                        color: _lightBg,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('فاتورة إلى:', style: pw.TextStyle(font: arabicBold, fontSize: 11, color: _textMuted)),
                          pw.SizedBox(height: 8),
                          pw.Text(customerName, style: pw.TextStyle(font: arabicBold, fontSize: 14, color: _textDark)),
                          pw.SizedBox(height: 4),
                          if (customerPhone.isNotEmpty)
                            pw.Text('الهاتف: $customerPhone', style: pw.TextStyle(font: arabicFont, fontSize: 11, color: _textDark)),
                          if (customerAddress.isNotEmpty)
                            pw.Text('العنوان: $customerAddress', style: pw.TextStyle(font: arabicFont, fontSize: 11, color: _textDark)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Payment Info
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _borderColor),
                        borderRadius: pw.BorderRadius.circular(8),
                        color: PdfColors.white,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('معلومات الدفع:', style: pw.TextStyle(font: arabicBold, fontSize: 11, color: _textMuted)),
                          pw.SizedBox(height: 8),
                          _paymentInfoLine('طريقة الدفع:', paymentLabel, arabicFont, paymentColor),
                          pw.SizedBox(height: 4),
                          _paymentInfoLine('حالة الفاتورة:', isCash ? 'مدفوعة' : 'مجدولة', arabicFont, _textDark),
                          pw.SizedBox(height: 4),
                          _paymentInfoLine('المبلغ الإجمالي:', '${currencyFormat.format(invoice.totalAmount)} ج.م', arabicBold, _textDark),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // ── ITEMS TABLE ────────────────────────────────────────────────
              pw.Text('تفاصيل الأصناف', style: pw.TextStyle(font: arabicBold, fontSize: 14, color: _textDark)),
              pw.SizedBox(height: 12),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _borderColor, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.5),  // Total
                    1: pw.FlexColumnWidth(1.5),  // Unit Price
                    2: pw.FlexColumnWidth(1),    // Qty
                    3: pw.FlexColumnWidth(4),    // Product
                    4: pw.FlexColumnWidth(0.5),  // #
                  },
                  children: itemRows,
                ),
              ),

              pw.SizedBox(height: 24),

              // ── TOTALS ─────────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: _lightBg,
                      border: pw.Border.all(color: _borderColor),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      children: [
                        _totalRow('المجموع الفرعي', '${currencyFormat.format(invoice.totalAmount)} ج.م', arabicFont, arabicBold),
                        pw.Divider(color: _borderColor, thickness: 1),
                        _totalRow('الإجمالي المستحق', '${currencyFormat.format(invoice.totalAmount)} ج.م', arabicBold, arabicBold, isTotal: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ── FOOTER ────────────────────────────────────────────────────
              pw.Divider(color: _borderColor, thickness: 1.5),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ملاحظات:', style: pw.TextStyle(font: arabicBold, fontSize: 10, color: _textDark)),
                      pw.SizedBox(height: 4),
                      pw.Text('1. البضاعة المباعة لا ترد ولا تستبدل إلا وفقاً لسياسة الشركة.', style: pw.TextStyle(font: arabicFont, fontSize: 9, color: _textMuted)),
                      pw.Text('2. شكراً لثقتكم بشركة زمزم للفلاتر.', style: pw.TextStyle(font: arabicFont, fontSize: 9, color: _textMuted)),
                    ],
                  ),
                  pw.Text('فاتورة ضريبية مبسطة', style: pw.TextStyle(font: arabicBold, fontSize: 10, color: _primaryColor)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  // ── Helper Builders ──────────────────────────────────────────────────────────

  static pw.Widget _paymentInfoLine(String label, String value, pw.Font font, PdfColor valueColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11, color: _textMuted)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11, color: valueColor)),
      ],
    );
  }

  static pw.Widget _headerCell(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      alignment: pw.Alignment.center,
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.white)),
    );
  }

  static pw.Widget _dataCell(String text, pw.Font font, {bool bold = false, bool center = false, bool muted = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      alignment: center ? pw.Alignment.center : pw.Alignment.centerRight,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          color: muted ? _textMuted : _textDark,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value, pw.Font font, pw.Font boldFont, {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: isTotal ? 14 : 11, color: isTotal ? _primaryColor : _textDark)),
          pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: isTotal ? 14 : 12, color: isTotal ? _primaryColor : _textDark)),
        ],
      ),
    );
  }
}
