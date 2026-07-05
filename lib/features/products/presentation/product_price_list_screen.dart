import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';

final allProductsForPriceListProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.products)
    ..where((t) => t.isDeleted.equals(false))
    ..orderBy([(t) => drift.OrderingTerm.asc(t.category), (t) => drift.OrderingTerm.asc(t.name)]);
  return query.get();
});

class ProductPriceListScreen extends ConsumerStatefulWidget {
  const ProductPriceListScreen({super.key});

  @override
  ConsumerState<ProductPriceListScreen> createState() => _ProductPriceListScreenState();
}

class _ProductPriceListScreenState extends ConsumerState<ProductPriceListScreen> {
  String _selectedCategory = 'الكل';
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsForPriceListProvider);

    return AppLayout(
      title: 'كشف أسعار المنتجات',
      child: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('خطأ: $err')),
        data: (products) {
          // Get unique categories
          final categories = ['الكل', ...{...products.map((p) => p.category)}];
          final filtered = _selectedCategory == 'الكل'
              ? products
              : products.where((p) => p.category == _selectedCategory).toList();

          return Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade700, Colors.blue.shade500],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'كشف أسعار المنتجات',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'إجمالي ${products.length} منتج',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _isGenerating ? null : () => _generatePdf(context, filtered),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_isGenerating ? 'جاري التصدير...' : 'تصدير PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Category filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                        selectedColor: Colors.indigo.shade100,
                        checkmarkColor: Colors.indigo,
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _summaryChip('إجمالي المنتجات', filtered.length.toString(), Colors.indigo),
                    const SizedBox(width: 8),
                    _summaryChip(
                      'متوسط سعر النقد',
                      filtered.isEmpty
                          ? '0'
                          : '${(filtered.fold(0.0, (s, p) => s + p.cashPrice) / filtered.length).toStringAsFixed(0)} ج.م',
                      Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Price table
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade700,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('#  اسم المنتج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text('الفئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text('سعر النقد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('سعر التقسيط', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('الجملة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Expanded(flex: 1, child: Text('المخزون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                      // Table rows
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final isEven = index.isEven;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isEven ? Colors.grey.shade50 : Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              borderRadius: index == filtered.length - 1
                                  ? const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${index + 1}. ${p.name}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      if (p.arabicName != null)
                                        Text(p.arabicName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    p.category,
                                    style: TextStyle(color: Colors.indigo.shade400, fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${p.cashPrice.toStringAsFixed(0)} ج.م',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${p.installmentPrice.toStringAsFixed(0)} ج.م',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${p.wholesalePrice.toStringAsFixed(0)} ج.م',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: p.currentStock == 0
                                          ? Colors.red.shade50
                                          : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${p.currentStock}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: p.currentStock == 0 ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text('لا توجد منتجات في هذه الفئة', style: TextStyle(color: Colors.grey.shade500)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, List<Product> products) async {
    setState(() => _isGenerating = true);
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      // Use a font that supports Arabic
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBoldFont = await PdfGoogleFonts.cairoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBoldFont),
          build: (pw.Context ctx) {
            return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('3949AB'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('شركة زمزم للفلاتر',
                            style: pw.TextStyle(font: arabicBoldFont, fontSize: 20, color: PdfColors.white)),
                        pw.Text('كشف أسعار المنتجات', style: pw.TextStyle(font: arabicFont, fontSize: 14, color: PdfColors.grey300)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('تاريخ الإصدار: $dateStr',
                            style: pw.TextStyle(font: arabicFont, fontSize: 12, color: PdfColors.white)),
                        pw.Text('إجمالي المنتجات: ${products.length}',
                            style: pw.TextStyle(font: arabicFont, fontSize: 12, color: PdfColors.grey300)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Table header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('3949AB')),
                    children: [
                      _pdfCell('اسم المنتج', arabicBoldFont, isHeader: true),
                      _pdfCell('الفئة', arabicBoldFont, isHeader: true),
                      _pdfCell('سعر النقد', arabicBoldFont, isHeader: true),
                      _pdfCell('سعر التقسيط', arabicBoldFont, isHeader: true),
                      _pdfCell('الجملة', arabicBoldFont, isHeader: true),
                      _pdfCell('المخزون', arabicBoldFont, isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...products.asMap().entries.map((e) {
                    final idx = e.key;
                    final p = e.value;
                    final isEven = idx.isEven;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.grey50 : PdfColors.white,
                      ),
                      children: [
                        _pdfCell('${idx + 1}. ${p.name}', arabicFont),
                        _pdfCell(p.category, arabicFont),
                        _pdfCell('${p.cashPrice.toStringAsFixed(0)} ج.م', arabicFont, color: PdfColors.green700),
                        _pdfCell('${p.installmentPrice.toStringAsFixed(0)} ج.م', arabicFont, color: PdfColors.purple),
                        _pdfCell('${p.wholesalePrice.toStringAsFixed(0)} ج.م', arabicFont, color: PdfColors.teal),
                        _pdfCell('${p.currentStock}', arabicFont,
                            color: p.currentStock == 0 ? PdfColors.red : PdfColors.green700),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('جميع الأسعار بالجنيه المصري',
                        style: pw.TextStyle(font: arabicFont, fontSize: 10, color: PdfColors.grey700)),
                    pw.Text('© زمزم للفلاتر - $dateStr',
                        style: pw.TextStyle(font: arabicFont, fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  pw.Widget _pdfCell(String text, pw.Font font, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.right,
      ),
    );
  }
}
