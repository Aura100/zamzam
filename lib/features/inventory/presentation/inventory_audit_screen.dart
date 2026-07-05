import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/widgets/app_layout.dart';

// Provider to load all products for audit
final inventoryAuditProductsProvider = FutureProvider<List<Product>>((ref) async {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.products)
    ..where((t) => t.isDeleted.equals(false))
    ..orderBy([(t) => drift.OrderingTerm.asc(t.category)]);
  return query.get();
});

// Provider to load audit history from inventory_audits table
final inventoryAuditHistoryProvider = FutureProvider<List<InventoryAudit>>((ref) async {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.inventoryAudits)
    ..orderBy([(t) => drift.OrderingTerm.desc(t.auditDate)]);
  return query.get();
});

class InventoryAuditScreen extends ConsumerStatefulWidget {
  const InventoryAuditScreen({super.key});

  @override
  ConsumerState<InventoryAuditScreen> createState() => _InventoryAuditScreenState();
}

class _InventoryAuditScreenState extends ConsumerState<InventoryAuditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRunningAudit = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(inventoryAuditProductsProvider);
    final historyAsync = ref.watch(inventoryAuditHistoryProvider);

    return AppLayout(
      title: 'الجرد الشهري للمخزون',
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.green.shade500],
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
                      'الجرد الشهري للمخزون',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'آخر تحديث: ${_formatDate(DateTime.now())}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isRunningAudit ? null : _runMonthlyAudit,
                      icon: _isRunningAudit
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.playlist_add_check),
                      label: Text(_isRunningAudit ? 'جاري الجرد...' : 'تشغيل جرد الآن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isGeneratingPdf
                          ? null
                          : () => _exportAuditPdf(context, productsAsync.value ?? []),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade900,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.teal.shade700,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal.shade700,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2), text: 'المخزون الحالي'),
              Tab(icon: Icon(Icons.history), text: 'سجل الجرد'),
            ],
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Current inventory
                productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (products) => _buildCurrentInventoryTab(products),
                ),
                // Tab 2: Audit history
                historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (history) => _buildAuditHistoryTab(history),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentInventoryTab(List<Product> products) {
    final totalValue = products.fold(0.0, (sum, p) => sum + (p.currentStock * p.purchasePrice));
    final totalItems = products.fold(0, (sum, p) => sum + p.currentStock);
    final zeroStock = products.where((p) => p.currentStock == 0).length;
    final lowStock = products.where((p) => p.currentStock > 0 && p.currentStock <= p.minStock).length;

    return Column(
      children: [
        // Summary cards
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _miniStatCard('إجمالي الأصناف', '${products.length}', Colors.blue),
              const SizedBox(width: 8),
              _miniStatCard('إجمالي الوحدات', '$totalItems', Colors.teal),
              const SizedBox(width: 8),
              _miniStatCard('قيمة المخزون', '${totalValue.toStringAsFixed(0)} ج.م', Colors.green),
              const SizedBox(width: 8),
              _miniStatCard('نفد المخزون', '$zeroStock', Colors.red),
              const SizedBox(width: 8),
              _miniStatCard('مخزون منخفض', '$lowStock', Colors.orange),
            ],
          ),
        ),

        // Products table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('#  اسم المنتج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('الفئة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 1, child: Text('المخزون', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('الحد الأدنى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('سعر الشراء', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('إجمالي القيمة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('الحالة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final isEven = index.isEven;
                    final totalVal = p.currentStock * p.purchasePrice;
                    String statusText;
                    Color statusColor;
                    if (p.currentStock == 0) {
                      statusText = 'نفد';
                      statusColor = Colors.red;
                    } else if (p.currentStock <= p.minStock) {
                      statusText = 'منخفض';
                      statusColor = Colors.orange;
                    } else {
                      statusText = 'جيد';
                      statusColor = Colors.green;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isEven ? Colors.grey.shade50 : Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text('${index + 1}. ${p.name}',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(p.category, style: TextStyle(color: Colors.teal.shade400, fontSize: 11)),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('${p.currentStock}', textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: statusColor, fontSize: 13)),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text('${p.minStock}', textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${p.purchasePrice.toStringAsFixed(0)} ج.م',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${totalVal.toStringAsFixed(0)} ج.م',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(statusText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditHistoryTab(List<InventoryAudit> history) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('لا يوجد سجل جرد بعد', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _runMonthlyAudit,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('تشغيل أول جرد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Group by date
    final Map<String, List<InventoryAudit>> grouped = {};
    for (final a in history) {
      final key = _formatDate(a.auditDate);
      grouped.putIfAbsent(key, () => []).add(a);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final items = grouped[date]!;
        final totalQty = items.fold(0, (sum, a) => sum + a.quantity);
        final totalVal = items.fold(0.0, (sum, a) => sum + (a.quantity * a.price));
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text('جرد يوم $date', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${items.length} صنف | ${totalQty} وحدة | ${totalVal.toStringAsFixed(0)} ج.م إجمالاً',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2, color: Colors.teal.shade700),
            ),
            children: items.map((a) => ListTile(
              dense: true,
              title: Text('منتج #${a.productId}', style: const TextStyle(fontSize: 13)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${a.quantity} وحدة', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('${(a.quantity * a.price).toStringAsFixed(0)} ج.م',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _miniStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 9), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _runMonthlyAudit() async {
    setState(() => _isRunningAudit = true);
    try {
      final db = ref.read(databaseProvider);
      final products = await (db.select(db.products)..where((t) => t.isDeleted.equals(false))).get();
      final now = DateTime.now();

      for (final p in products) {
        await db.into(db.inventoryAudits).insert(
          InventoryAuditsCompanion.insert(
            productId: p.id,
            quantity: p.currentStock,
            price: drift.Value(p.purchasePrice),
            auditDate: drift.Value(now),
          ),
        );
      }

      ref.invalidate(inventoryAuditHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تنفيذ الجرد بنجاح - ${products.length} صنف'),
            backgroundColor: Colors.green,
          ),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تنفيذ الجرد: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRunningAudit = false);
    }
  }

  Future<void> _exportAuditPdf(BuildContext context, List<Product> products) async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات للتصدير')),
      );
      return;
    }
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = _formatDate(now);
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicBoldFont = await PdfGoogleFonts.cairoBold();
      final totalValue = products.fold(0.0, (s, p) => s + p.currentStock * p.purchasePrice);
      final totalItems = products.fold(0, (s, p) => s + p.currentStock);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBoldFont),
          build: (pw.Context ctx) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('00695C'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('شركة زمزم للفلاتر',
                          style: pw.TextStyle(font: arabicBoldFont, fontSize: 18, color: PdfColors.white)),
                      pw.Text('تقرير الجرد الشهري - $dateStr',
                          style: pw.TextStyle(font: arabicFont, fontSize: 12, color: PdfColors.grey300)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('إجمالي الوحدات: $totalItems',
                          style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.white)),
                      pw.Text('إجمالي القيمة: ${totalValue.toStringAsFixed(0)} ج.م',
                          style: pw.TextStyle(font: arabicBoldFont, fontSize: 12, color: PdfColors.white)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('00695C')),
                  children: [
                    _pdfCell('اسم المنتج', arabicBoldFont, isHeader: true),
                    _pdfCell('الفئة', arabicBoldFont, isHeader: true),
                    _pdfCell('المخزون', arabicBoldFont, isHeader: true),
                    _pdfCell('سعر الشراء', arabicBoldFont, isHeader: true),
                    _pdfCell('إجمالي القيمة', arabicBoldFont, isHeader: true),
                    _pdfCell('الحالة', arabicBoldFont, isHeader: true),
                  ],
                ),
                ...products.asMap().entries.map((e) {
                  final idx = e.key;
                  final p = e.value;
                  final val = p.currentStock * p.purchasePrice;
                  String st = p.currentStock == 0 ? 'نفد' : p.currentStock <= p.minStock ? 'منخفض' : 'جيد';
                  PdfColor stColor = p.currentStock == 0
                      ? PdfColors.red
                      : p.currentStock <= p.minStock
                          ? PdfColors.orange
                          : PdfColors.green700;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: idx.isEven ? PdfColors.grey50 : PdfColors.white),
                    children: [
                      _pdfCell('${idx + 1}. ${p.name}', arabicFont),
                      _pdfCell(p.category, arabicFont),
                      _pdfCell('${p.currentStock}', arabicFont,
                          color: p.currentStock == 0 ? PdfColors.red : PdfColors.black),
                      _pdfCell('${p.purchasePrice.toStringAsFixed(0)} ج.م', arabicFont),
                      _pdfCell('${val.toStringAsFixed(0)} ج.م', arabicFont, color: PdfColors.green700),
                      _pdfCell(st, arabicFont, color: stColor),
                    ],
                  );
                }),
              ],
            ),
          ],
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
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  pw.Widget _pdfCell(String text, pw.Font font, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
          color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
        ),
        textAlign: pw.TextAlign.right,
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
