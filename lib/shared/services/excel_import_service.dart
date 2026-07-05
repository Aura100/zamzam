import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../features/customers/data/customers_repository.dart';
import '../../features/customers/presentation/customers_providers.dart';

class ExcelImportService {
  final AppDatabase _db;
  final CustomersRepository _customersRepo;

  ExcelImportService(this._db, this._customersRepo);

  /// 1. إنشاء وتحميل قالب الإكسيل الفارغ
  Future<void> exportTemplate() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['العملاء'];
    excel.setDefaultSheet('العملاء');

    // Headers
    sheetObject.cell(CellIndex.indexByString('A1')).value = TextCellValue('اسم العميل (إلزامي)');
    sheetObject.cell(CellIndex.indexByString('B1')).value = TextCellValue('رقم الهاتف (إلزامي)');
    sheetObject.cell(CellIndex.indexByString('C1')).value = TextCellValue('العنوان');
    sheetObject.cell(CellIndex.indexByString('D1')).value = TextCellValue('معرف المنتج (Product ID) (إلزامي)');
    sheetObject.cell(CellIndex.indexByString('E1')).value = TextCellValue('دورة الصيانة بالأشهر (رقم)');
    sheetObject.cell(CellIndex.indexByString('F1')).value = TextCellValue('تاريخ الشراء (YYYY-MM-DD)');
    sheetObject.cell(CellIndex.indexByString('G1')).value = TextCellValue('تاريخ آخر صيانة (YYYY-MM-DD)');
    sheetObject.cell(CellIndex.indexByString('H1')).value = TextCellValue('المديونية المتبقية (أرقام)');

    // Sample data
    sheetObject.cell(CellIndex.indexByString('A2')).value = TextCellValue('محمد السيد');
    sheetObject.cell(CellIndex.indexByString('B2')).value = TextCellValue('01012345678');
    sheetObject.cell(CellIndex.indexByString('C2')).value = TextCellValue('القاهرة - التجمع');
    sheetObject.cell(CellIndex.indexByString('D2')).value = IntCellValue(1);
    sheetObject.cell(CellIndex.indexByString('E2')).value = IntCellValue(3);
    sheetObject.cell(CellIndex.indexByString('F2')).value = TextCellValue('2023-01-01');
    sheetObject.cell(CellIndex.indexByString('G2')).value = TextCellValue('2023-12-01');
    sheetObject.cell(CellIndex.indexByString('H2')).value = IntCellValue(1500);

    final String fileName = 'قالب_استيراد_العملاء.xlsx';
    final FileSaveLocation? result = await getSaveLocation(suggestedName: fileName);
    if (result != null) {
      final List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        final file = File(result.path);
        await file.writeAsBytes(fileBytes);
      }
    }
  }

  /// 2. قراءة ملف الإكسيل وإدخال البيانات
  Future<String> importCustomers() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Excel Files',
      extensions: <String>['xlsx', 'xls'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    
    if (file == null) return 'تم إلغاء العملية';

    try {
      var bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      
      int successCount = 0;
      int errorCount = 0;

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table]!;
        // Skip header row
        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty || row[0]?.value == null) continue;

          try {
            final name = row[0]!.value.toString();
            final phone = row[1]?.value?.toString() ?? '';
            final address = row[2]?.value?.toString() ?? '';
            final productIdStr = row[3]?.value?.toString() ?? '0';
            final cycleStr = row[4]?.value?.toString() ?? '3';
            final purchaseDateStr = row[5]?.value?.toString();
            final lastMaintDateStr = row[6]?.value?.toString();
            final debtStr = row[7]?.value?.toString() ?? '0';

            final productId = int.tryParse(productIdStr) ?? 1;
            final cycleMonths = int.tryParse(cycleStr) ?? 3;
            final debt = double.tryParse(debtStr) ?? 0.0;

            DateTime purchaseDate = DateTime.now().subtract(const Duration(days: 365));
            if (purchaseDateStr != null && purchaseDateStr.isNotEmpty) {
              purchaseDate = DateTime.tryParse(purchaseDateStr) ?? purchaseDate;
            }

            DateTime lastMaintDate = purchaseDate;
            if (lastMaintDateStr != null && lastMaintDateStr.isNotEmpty) {
              lastMaintDate = DateTime.tryParse(lastMaintDateStr) ?? lastMaintDate;
            }

            final customer = CustomersCompanion.insert(
              name: name,
              phone1: phone,
              address: drift.Value(address.isNotEmpty ? address : null),
            );

            await _customersRepo.addLegacyCustomer(
              customer: customer,
              productId: productId,
              purchaseDate: purchaseDate,
              lastMaintenanceDate: lastMaintDate,
              cycleMonths: cycleMonths,
              remainingDebt: debt,
            );
            
            successCount++;
          } catch (e) {
            errorCount++;
          }
        }
      }
      return 'تم استيراد $successCount عميل بنجاح' + (errorCount > 0 ? ' (فشل $errorCount بسبب أخطاء في البيانات)' : '');
    } catch (e) {
      return 'حدث خطأ أثناء قراءة الملف: $e';
    }
  }
}

final excelImportServiceProvider = Provider<ExcelImportService>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(customersRepositoryProvider);
  return ExcelImportService(db, repo);
});
