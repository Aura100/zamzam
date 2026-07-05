import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';

class MaintenancePrinter {
  // Brand colors
  static const _primary = PdfColor.fromInt(0xFF0F3460);
  static const _accent = PdfColor.fromInt(0xFF1A6FA8);
  static const _light = PdfColor.fromInt(0xFFF4F8FF);
  static const _border = PdfColor.fromInt(0xFFCFDCEA);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _dark = PdfColor.fromInt(0xFF111827);
  static const _orange = PdfColor.fromInt(0xFFEA580C);

  // ─── MAINTENANCE INVOICE (customer copy) ─────────────────────────────────
  static Future<void> printInvoice({
    required MaintenanceRequest request,
    required Customer customer,
    required List<MaintenancePart> parts,
    required List<Product> allProducts,
    required String technicianName,
    String companyName = 'مؤسسة زمزم فلاتر المياه',
    String companyPhone = '',
    String companyAddress = 'القاهرة، مصر',
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();
    final dateFmt = DateFormat('yyyy/MM/dd');
    final numFmt = NumberFormat('#,##0.00');

    final usedParts = parts.where((p) => p.quantityUsed > 0).toList();
    final partsTotal =
        usedParts.fold(0.0, (s, p) => s + p.quantityUsed * p.unitPrice);
    final serviceCost = request.cost - partsTotal;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            font: arabicBold, fontSize: 22, color: _primary)),
                    pw.SizedBox(height: 4),
                    if (companyPhone.isNotEmpty)
                      pw.Text('هاتف: $companyPhone',
                          style: pw.TextStyle(
                              font: arabicFont, fontSize: 10, color: _muted)),
                    pw.Text('العنوان: $companyAddress',
                        style: pw.TextStyle(
                            font: arabicFont, fontSize: 10, color: _muted)),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: pw.BoxDecoration(
                          color: _primary,
                          borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Text('فاتورة صيانة',
                          style: pw.TextStyle(
                              font: arabicBold,
                              fontSize: 16,
                              color: PdfColors.white)),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('#MNT-${request.id}',
                        style: pw.TextStyle(
                            font: arabicBold, fontSize: 13, color: _dark)),
                    pw.Text(
                        'التاريخ: ${dateFmt.format(request.completionDate ?? request.scheduledDate)}',
                        style: pw.TextStyle(
                            font: arabicFont, fontSize: 10, color: _muted)),
                  ]),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── Info Cards ──────────────────────────────────────────────────
          pw.Row(children: [
            pw.Expanded(
              flex: 3,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                    color: _light,
                    border: pw.Border.all(color: _border),
                    borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('بيانات العميل',
                          style: pw.TextStyle(
                              font: arabicBold, fontSize: 10, color: _muted)),
                      pw.Divider(color: _border, height: 10),
                      pw.Text(customer.name,
                          style: pw.TextStyle(
                              font: arabicBold, fontSize: 13, color: _dark)),
                      pw.SizedBox(height: 3),
                      pw.Text('الهاتف: ${customer.phone1}',
                          style: pw.TextStyle(
                              font: arabicFont, fontSize: 10, color: _dark)),
                      if (customer.address != null &&
                          customer.address!.isNotEmpty)
                        pw.Text('العنوان: ${customer.address}',
                            style: pw.TextStyle(
                                font: arabicFont, fontSize: 10, color: _dark)),
                    ]),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 2,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _border),
                    borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('تفاصيل الخدمة',
                          style: pw.TextStyle(
                              font: arabicBold, fontSize: 10, color: _muted)),
                      pw.Divider(color: _border, height: 10),
                      pw.Text('الفني: $technicianName',
                          style: pw.TextStyle(
                              font: arabicFont, fontSize: 11, color: _dark)),
                      pw.SizedBox(height: 3),
                      pw.Text('المشكلة: ${request.issueDescription}',
                          style: pw.TextStyle(
                              font: arabicFont, fontSize: 9, color: _dark)),
                    ]),
              ),
            ),
          ]),
          pw.SizedBox(height: 20),

          // ── Parts Table ──────────────────────────────────────────────────
          if (usedParts.isNotEmpty) ...[
            pw.Text('قطع الغيار المستخدمة',
                style:
                    pw.TextStyle(font: arabicBold, fontSize: 12, color: _dark)),
            pw.SizedBox(height: 8),
            pw.Container(
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(4),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2)
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: _primary,
                        borderRadius: pw.BorderRadius.vertical(
                            top: pw.Radius.circular(6))),
                    children: [
                      _hCell('الصنف', arabicBold),
                      _hCell('الكمية', arabicBold),
                      _hCell('سعر الوحدة', arabicBold),
                      _hCell('الإجمالي', arabicBold),
                    ],
                  ),
                  ...usedParts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final part = entry.value;
                    final prod = allProducts.firstWhere(
                        (p) => p.id == part.productId,
                        orElse: () => allProducts.first);
                    final total = part.quantityUsed * part.unitPrice;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: i.isEven ? _light : PdfColors.white),
                      children: [
                        _dCell(prod.name, arabicFont),
                        _dCell('${part.quantityUsed}', arabicFont,
                            center: true),
                        _dCell('${numFmt.format(part.unitPrice)} ج.م',
                            arabicFont),
                        _dCell('${numFmt.format(total)} ج.م', arabicFont,
                            bold: true),
                      ],
                    );
                  }),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Totals ───────────────────────────────────────────────────────
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              width: 260,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                  color: _light,
                  border: pw.Border.all(color: _border),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(children: [
                if (usedParts.isNotEmpty) ...[
                  _totalRow('تكلفة الخدمة',
                      '${numFmt.format(serviceCost)} ج.م', arabicFont, arabicBold),
                  _totalRow('تكلفة القطع',
                      '${numFmt.format(partsTotal)} ج.م', arabicFont, arabicBold),
                  pw.Divider(color: _border),
                ],
                _totalRow('الإجمالي المستحق',
                    '${numFmt.format(request.cost)} ج.م', arabicBold, arabicBold,
                    isTotal: true),
              ]),
            ),
          ]),

          pw.Spacer(),

          // ── Footer ───────────────────────────────────────────────────────
          pw.Divider(color: _border),
          pw.SizedBox(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('شكراً لثقتكم بنا 💧',
                    style: pw.TextStyle(
                        font: arabicBold, fontSize: 11, color: _primary)),
                pw.Text('فاتورة خدمة صيانة رسمية',
                    style: pw.TextStyle(
                        font: arabicFont, fontSize: 9, color: _muted)),
              ]),
        ],
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: 'Maintenance_Invoice_${request.id}',
    );
  }

  // ─── RETURN INVOICE (technician returning unused parts) ──────────────────
  static Future<void> printReturnInvoice({
    required int requestId,
    required String technicianName,
    required List<({String productName, int quantity, double unitPrice})>
        returnedItems,
    String companyName = 'مؤسسة زمزم فلاتر المياه',
    String companyPhone = '',
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');
    final numFmt = NumberFormat('#,##0.00');

    final totalValue =
        returnedItems.fold(0.0, (s, i) => s + i.quantity * i.unitPrice);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            font: arabicBold, fontSize: 22, color: _primary)),
                    pw.SizedBox(height: 4),
                    if (companyPhone.isNotEmpty)
                      pw.Text('هاتف: $companyPhone',
                          style: pw.TextStyle(
                              font: arabicFont, fontSize: 10, color: _muted)),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: pw.BoxDecoration(
                          color: _orange,
                          borderRadius: pw.BorderRadius.circular(6)),
                      child: pw.Text('إيصال مرتجع قطع',
                          style: pw.TextStyle(
                              font: arabicBold,
                              fontSize: 15,
                              color: PdfColors.white)),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('مرجع: #MNT-$requestId',
                        style: pw.TextStyle(
                            font: arabicBold, fontSize: 13, color: _dark)),
                    pw.Text('التاريخ: ${dateFmt.format(DateTime.now())}',
                        style: pw.TextStyle(
                            font: arabicFont, fontSize: 10, color: _muted)),
                  ]),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── Technician Box ───────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
                color: _light,
                border: pw.Border.all(color: _border),
                borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(children: [
              pw.Text('اسم الفني:',
                  style: pw.TextStyle(
                      font: arabicBold, fontSize: 12, color: _muted)),
              pw.SizedBox(width: 8),
              pw.Text(technicianName,
                  style: pw.TextStyle(
                      font: arabicBold, fontSize: 14, color: _dark)),
              pw.Spacer(),
              pw.Text('طلب الصيانة رقم:',
                  style: pw.TextStyle(
                      font: arabicFont, fontSize: 11, color: _muted)),
              pw.SizedBox(width: 6),
              pw.Text('#$requestId',
                  style: pw.TextStyle(
                      font: arabicBold, fontSize: 13, color: _accent)),
            ]),
          ),
          pw.SizedBox(height: 20),

          // ── Returned Items Table ─────────────────────────────────────────
          pw.Text('القطع المُرجعة إلى المخزن',
              style:
                  pw.TextStyle(font: arabicBold, fontSize: 12, color: _dark)),
          pw.SizedBox(height: 8),
          pw.Container(
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _border),
                borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2)
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: _orange,
                      borderRadius: pw.BorderRadius.vertical(
                          top: pw.Radius.circular(6))),
                  children: [
                    _hCell('الصنف', arabicBold),
                    _hCell('الكمية', arabicBold),
                    _hCell('سعر الوحدة', arabicBold),
                    _hCell('القيمة الإجمالية', arabicBold),
                  ],
                ),
                ...returnedItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: i.isEven ? _light : PdfColors.white),
                    children: [
                      _dCell(item.productName, arabicFont),
                      _dCell('${item.quantity}', arabicFont, center: true),
                      _dCell('${numFmt.format(item.unitPrice)} ج.م', arabicFont),
                      _dCell(
                          '${numFmt.format(item.quantity * item.unitPrice)} ج.م',
                          arabicFont,
                          bold: true),
                    ],
                  );
                }),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Total ─────────────────────────────────────────────────────────
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              width: 260,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                  color: _light,
                  border: pw.Border.all(color: _border),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: _totalRow('إجمالي قيمة المرتجع',
                  '${numFmt.format(totalValue)} ج.م', arabicBold, arabicBold,
                  isTotal: true),
            ),
          ]),

          pw.Spacer(),

          // ── Signature Lines ───────────────────────────────────────────────
          pw.SizedBox(height: 30),
          pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                          width: 150,
                          height: 1,
                          decoration:
                              const pw.BoxDecoration(color: _border)),
                      pw.SizedBox(height: 4),
                      pw.Text('توقيع الفني',
                          style: pw.TextStyle(
                              font: arabicFont, fontSize: 10, color: _muted)),
                    ]),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                          width: 150,
                          height: 1,
                          decoration:
                              const pw.BoxDecoration(color: _border)),
                      pw.SizedBox(height: 4),
                      pw.Text('توقيع أمين المخزن',
                          style: pw.TextStyle(
                              font: arabicFont, fontSize: 10, color: _muted)),
                    ]),
              ]),

          pw.SizedBox(height: 16),
          pw.Divider(color: _border),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
                'هذا الإيصال يُثبت إرجاع القطع المذكورة إلى مخزن الشركة بتاريخ ${dateFmt.format(DateTime.now())}',
                style: pw.TextStyle(
                    font: arabicFont, fontSize: 9, color: _muted)),
          ),
        ],
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(),
      name: 'Return_Invoice_MNT_$requestId',
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  static pw.Widget _hCell(String text, pw.Font font) => pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: pw.TextStyle(
                font: font, fontSize: 10, color: PdfColors.white)),
      );

  static pw.Widget _dCell(String text, pw.Font font,
          {bool bold = false, bool center = false}) =>
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        alignment:
            center ? pw.Alignment.center : pw.Alignment.centerRight,
        child: pw.Text(text,
            style: pw.TextStyle(
                font: font,
                fontSize: 10,
                fontWeight: bold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal)),
      );

  static pw.Widget _totalRow(
          String label, String value, pw.Font font, pw.Font boldFont,
          {bool isTotal = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: font,
                      fontSize: isTotal ? 13 : 11,
                      color: isTotal ? _primary : _dark)),
              pw.Text(value,
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: isTotal ? 14 : 11,
                      color: isTotal ? _primary : _dark)),
            ]),
      );
}
