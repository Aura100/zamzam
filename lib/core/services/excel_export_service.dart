import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

class ExcelExportService {
  static Future<bool> exportToExcel({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Add headers
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Add rows
      for (final row in rows) {
        sheet.appendRow(row.map((cell) {
          if (cell == null) return TextCellValue('');
          return TextCellValue(cell.toString());
        }).toList());
      }

      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: '$filename.xlsx',
      );

      if (saveLocation != null) {
        final bytes = excel.encode();
        if (bytes != null) {
          final file = File(saveLocation.path);
          await file.writeAsBytes(bytes);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
