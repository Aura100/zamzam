import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/archive_analysis_service.dart';
import '../../../core/services/database_archive_service.dart';
import '../../../core/services/excel_export_service.dart';

class MonthlyArchivesScreen extends ConsumerStatefulWidget {
  const MonthlyArchivesScreen({super.key});

  @override
  ConsumerState<MonthlyArchivesScreen> createState() =>
      _MonthlyArchivesScreenState();
}

class _MonthlyArchivesScreenState extends ConsumerState<MonthlyArchivesScreen> {
  List<MonthlyArchiveEntry> _archives = [];
  bool _isLoading = true;
  MonthlyArchiveEntry? _selectedMonth;
  File? _selectedArchiveFile;
  ArchiveAnalysisResult? _analysisResult;
  bool _isAnalyzing = false;
  final Map<String, ArchiveAnalysisResult> _analysisCache = {};

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() {
      _isLoading = true;
      _analysisResult = null;
      _selectedArchiveFile = null;
      _selectedMonth = null;
    });

    final archives = await DatabaseArchiveService.listMonthlyArchives();
    if (!mounted) return;

    setState(() {
      _archives = archives;
      _isLoading = false;
      if (archives.isNotEmpty) {
        _selectedMonth = archives.first;
        _selectedArchiveFile = archives.first.files.isNotEmpty
            ? archives.first.files.first
            : null;
      }
    });

    if (_selectedArchiveFile != null) {
      await _analyzeArchiveFile(_selectedArchiveFile!);
    }
  }

  Future<void> _analyzeArchiveFile(File file) async {
    setState(() {
      _isAnalyzing = true;
    });

    final cacheKey = file.path;
    if (_analysisCache.containsKey(cacheKey)) {
      if (!mounted) return;
      setState(() {
        _analysisResult = _analysisCache[cacheKey];
        _isAnalyzing = false;
      });
      return;
    }

    try {
      final analysis = await ArchiveAnalysisService.analyzeArchive(file.path);
      if (!mounted) return;
      setState(() {
        _analysisCache[cacheKey] = analysis;
        _analysisResult = analysis;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analysisResult = null;
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحميل تحليلات الأرشيف: $e')));
    }
  }

  Future<void> _createArchive() async {
    try {
      final archivePath = await DatabaseArchiveService.createManualArchive();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء أرشيف جديد: $archivePath')),
      );
      await _loadArchives();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل إنشاء الأرشيف: $e')));
    }
  }

  Future<void> _restoreArchive(File archiveFile) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('استعادة أرشيف'),
          content: Text(
            'هل تريد استعادة الأرشيف: ${p.basename(archiveFile.path)} ؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      await DatabaseArchiveService.restoreArchive(archiveFile: archiveFile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت استعادة الأرشيف بنجاح. يرجى إعادة تشغيل التطبيق.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل استعادة الأرشيف: $e')));
    }
  }

  Future<void> _exportArchiveReport() async {
    if (_analysisResult == null || _selectedArchiveFile == null) return;

    final result = _analysisResult!;
    final filename = 'تقرير_الأرشيف_${_selectedMonth?.monthKey ?? 'غير_محدد'}';
    final rows = <List<dynamic>>[];

    rows.add(['ملخص الأرشيف', '']);
    rows.add(['إجمالي الفواتير', result.totalInvoices]);
    rows.add(['إجمالي المبيعات', result.totalSales.toStringAsFixed(2)]);
    rows.add(['العملاء', result.totalCustomers]);
    rows.add(['المنتجات المباعة', result.totalProductsSold]);
    rows.add(['إجمالي الخصومات', result.totalDiscount.toStringAsFixed(2)]);
    rows.add(['إجمالي الصيانات', result.totalMaintenanceRequests]);
    rows.add(['الصيانات الداخلية', result.totalInternalMaintenance]);
    rows.add(['الصيانات الخارجية', result.totalExternalMaintenance]);
    rows.add([
      'إجمالي عمولات الفنيين',
      result.totalMaintenanceCommissionAmount.toStringAsFixed(2),
    ]);
    rows.add(['إجمالي معاملات الرواتب', result.totalPayrollTransactions]);
    rows.add([
      'إجمالي الرواتب/المكافآت',
      result.totalPayrollAmount.toStringAsFixed(2),
    ]);
    rows.add(['', '']);
    rows.add(['المبيعات اليومية', '']);
    rows.add(['التاريخ', 'قيمة المبيعات']);
    rows.addAll(
      result.dailySales.entries.map(
        (entry) => [entry.key, entry.value.toStringAsFixed(2)],
      ),
    );
    rows.add(['', '']);
    rows.add(['أهم المنتجات', '']);
    rows.add(['المنتج', 'الكمية', 'الإيراد']);
    rows.addAll(
      result.topProducts.map(
        (product) => [
          product.productName,
          product.quantity,
          product.revenue.toStringAsFixed(2),
        ],
      ),
    );

    final success = await ExcelExportService.exportToExcel(
      filename: filename,
      headers: ['الحقل', 'القيمة', 'بيان'],
      rows: rows,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '✅ تم تصدير التقرير بنجاح' : '❌ فشل تصدير التقرير',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحليل الأرشيف الشهري'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadArchives,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _analysisResult != null ? _exportArchiveReport : null,
            tooltip: 'تصدير Excel',
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: _createArchive,
            tooltip: 'إنشاء أرشيف جديد',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archives.isEmpty
          ? _buildEmptyState(context)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOverviewHeader(context),
                  const SizedBox(height: 16),
                  Expanded(child: _buildArchiveDashboard(context)),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 72, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'لا توجد أرشيفات شهرية بعد',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'سيظهر هنا تقرير تحليلي لكل شهر بعد حفظ الأرشيف.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewHeader(BuildContext context) {
    final selectedFileName = _selectedArchiveFile != null
        ? p.basename(_selectedArchiveFile!.path)
        : 'لم يتم اختيار ملف';
    final monthTitle = _selectedMonth?.monthKey ?? 'الشهر الحالي';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'التقرير التحليلي لشهر $monthTitle',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: 4),
        Text(
          'أرشيف: $selectedFileName',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildArchiveDashboard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 380, child: _buildArchiveList(context)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildAnalysisPanel(context)),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 2, child: _buildArchiveList(context)),
                  const SizedBox(height: 16),
                  Expanded(flex: 3, child: _buildAnalysisPanel(context)),
                ],
              );
      },
    );
  }

  Widget _buildArchiveList(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'أرشيفات الشهر',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _archives.length,
                itemBuilder: (context, index) {
                  final month = _archives[index];
                  final isSelectedMonth =
                      month.monthKey == _selectedMonth?.monthKey;
                  return Card(
                    color: isSelectedMonth ? Colors.blue.shade50 : null,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      initiallyExpanded: isSelectedMonth,
                      leading: const Icon(Icons.folder, color: Colors.blue),
                      title: Text(
                        month.monthKey,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${month.files.length} ملف أرشيف'),
                      children: month.files.map((file) {
                        final fileName = p.basename(file.path);
                        final isSelectedFile =
                            file.path == _selectedArchiveFile?.path;
                        final stat = file.statSync();
                        final fileSize = _formatSize(stat.size);
                        final modifiedAt =
                            '${stat.modified.year}/${stat.modified.month.toString().padLeft(2, '0')}/${stat.modified.day.toString().padLeft(2, '0')}';

                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            selected: isSelectedFile,
                            selectedTileColor: Colors.blue.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            leading: const Icon(
                              Icons.insert_drive_file,
                              color: Colors.green,
                            ),
                            title: Text(
                              fileName,
                              style: TextStyle(
                                fontWeight: isSelectedFile
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text('$fileSize • $modifiedAt'),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.restore,
                                color: Colors.orange,
                              ),
                              tooltip: 'استعادة هذا الأرشيف',
                              onPressed: () => _restoreArchive(file),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedMonth = month;
                                _selectedArchiveFile = file;
                              });
                              _analyzeArchiveFile(file);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisPanel(BuildContext context) {
    if (_selectedArchiveFile == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Text(
            'اختر ملف أرشيف لعرض التحليلات',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _isAnalyzing
            ? const Center(child: CircularProgressIndicator())
            : _analysisResult == null
            ? Center(
                child: Text(
                  'فشل تحميل بيانات التحليل.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ملخص شهري',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryGrid(context),
                    const SizedBox(height: 16),
                    _buildSalesChartCard(context),
                    const SizedBox(height: 16),
                    _buildTopProductsCard(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryGrid(BuildContext context) {
    final result = _analysisResult!;
    return Wrap(
      runSpacing: 12,
      spacing: 12,
      children: [
        _buildMetricCard(
          'إجمالي الفواتير',
          result.totalInvoices.toString(),
          Colors.blue,
        ),
        _buildMetricCard(
          'إجمالي المبيعات',
          result.totalSales.toStringAsFixed(2),
          Colors.green,
        ),
        _buildMetricCard(
          'العملاء',
          result.totalCustomers.toString(),
          Colors.teal,
        ),
        _buildMetricCard(
          'المنتجات المباعة',
          result.totalProductsSold.toString(),
          Colors.purple,
        ),
        _buildMetricCard(
          'إجمالي الخصومات',
          result.totalDiscount.toStringAsFixed(2),
          Colors.orange,
        ),
        _buildMetricCard(
          'الصيانات',
          result.totalMaintenanceRequests.toString(),
          Colors.deepOrange,
        ),
        _buildMetricCard(
          'العمولات',
          result.totalMaintenanceCommissionAmount.toStringAsFixed(2),
          Colors.indigo,
        ),
        _buildMetricCard(
          'الرواتب',
          result.totalPayrollAmount.toStringAsFixed(2),
          Colors.brown,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, MaterialColor color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.16 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color.shade700)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChartCard(BuildContext context) {
    final result = _analysisResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'المبيعات اليومية',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 260, child: _buildDailySalesChart(result.dailySales)),
      ],
    );
  }

  Widget _buildDailySalesChart(Map<String, double> dailySales) {
    if (dailySales.isEmpty) {
      return const Center(child: Text('لا توجد حركة مبيعات في هذا الأرشيف.'));
    }

    final entries = dailySales.entries.toList();
    final maxY =
        (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.25)
            .clamp(1.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length)
                  return const SizedBox.shrink();
                final label = entries[index].key.split('-').last;
                return SideTitleWidget(
                  meta: meta,
                  space: 4,
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 36,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 44),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(entries.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entries[index].value,
                color: Colors.blue.shade700,
                width: 18,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTopProductsCard(BuildContext context) {
    final result = _analysisResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'أهم المنتجات',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Material(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
            columns: const [
              DataColumn(label: Text('المنتج')),
              DataColumn(label: Text('الكمية')),
              DataColumn(label: Text('الإيراد')),
            ],
            rows: result.topProducts.map((product) {
              return DataRow(
                cells: [
                  DataCell(Text(product.productName)),
                  DataCell(Text(product.quantity.toString())),
                  DataCell(Text(product.revenue.toStringAsFixed(2))),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
