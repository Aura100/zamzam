import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../shared/widgets/app_layout.dart';
import '../../../core/database/app_database.dart';
import 'products_providers.dart';

class BarcodeLabelScreen extends ConsumerStatefulWidget {
  const BarcodeLabelScreen({super.key});

  @override
  ConsumerState<BarcodeLabelScreen> createState() => _BarcodeLabelScreenState();
}

class _BarcodeLabelScreenState extends ConsumerState<BarcodeLabelScreen> {
  final Set<int> _selectedProductIds = {};
  int _labelsPerProduct = 1;
  String _searchQuery = '';

  Future<Uint8List> _generatePdf(List<Product> products) async {
    final pdf = pw.Document();
    final selectedProducts = products.where((p) => _selectedProductIds.contains(p.id)).toList();

    if (selectedProducts.isEmpty) return pdf.save();

    // Build all labels
    final List<pw.Widget> labels = [];
    for (final product in selectedProducts) {
      for (int i = 0; i < _labelsPerProduct; i++) {
        final barcodeText = product.barcode ?? product.sku ?? product.id.toString();
        labels.add(
          pw.Container(
            width: 180,
            height: 90,
            margin: const pw.EdgeInsets.all(4),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcodeText,
                  width: 150,
                  height: 40,
                  drawText: false,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  barcodeText,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  product.name.length > 25 ? '${product.name.substring(0, 25)}...' : product.name,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Text(
                  '${product.cashPrice.toStringAsFixed(0)} ج.م',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Layout labels in grid 3x per row
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (ctx) => [
          pw.Wrap(children: labels),
        ],
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    return AppLayout(
      title: 'طباعة ملصقات الباركود',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن منتج...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase().trim()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('عدد الملصقات لكل منتج:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: _labelsPerProduct > 1 ? () => setState(() => _labelsPerProduct--) : null,
                              ),
                              Text('$_labelsPerProduct', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                onPressed: () => setState(() => _labelsPerProduct++),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _selectedProductIds.isEmpty
                          ? null
                          : () async {
                              final products = productsAsync.valueOrNull ?? [];
                              final pdfBytes = await _generatePdf(products);
                              if (!context.mounted) return;
                              await Printing.layoutPdf(onLayout: (_) => pdfBytes);
                            },
                      icon: const Icon(Icons.print),
                      label: Text('طباعة (${_selectedProductIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Products list
            Expanded(
              child: Card(
                child: productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (products) {
                    final filtered = _searchQuery.isEmpty
                        ? products
                        : products.where((p) =>
                            p.name.toLowerCase().contains(_searchQuery) ||
                            (p.barcode ?? '').toLowerCase().contains(_searchQuery) ||
                            (p.sku ?? '').toLowerCase().contains(_searchQuery)).toList();

                    return Column(
                      children: [
                        // Select all / clear
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.select_all),
                                label: const Text('تحديد الكل'),
                                onPressed: () => setState(() {
                                  _selectedProductIds.addAll(filtered.map((p) => p.id));
                                }),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.deselect),
                                label: const Text('إلغاء التحديد'),
                                onPressed: () => setState(() => _selectedProductIds.clear()),
                              ),
                              const Spacer(),
                              Text('${_selectedProductIds.length} منتج محدد', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final p = filtered[i];
                              final selected = _selectedProductIds.contains(p.id);
                              final barcodeText = p.barcode ?? p.sku ?? p.id.toString();

                              return ListTile(
                                leading: Checkbox(
                                  value: selected,
                                  onChanged: (_) => setState(() {
                                    if (selected) {
                                      _selectedProductIds.remove(p.id);
                                    } else {
                                      _selectedProductIds.add(p.id);
                                    }
                                  }),
                                ),
                                title: Text(p.name),
                                subtitle: Text('كود: $barcodeText | السعر: ${p.cashPrice} ج.م'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    barcodeText,
                                    style: TextStyle(fontFamily: 'Courier', color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                onTap: () => setState(() {
                                  if (selected) {
                                    _selectedProductIds.remove(p.id);
                                  } else {
                                    _selectedProductIds.add(p.id);
                                  }
                                }),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
