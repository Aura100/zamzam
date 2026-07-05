import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

class MonthlyArchiveEntry {
  final String monthKey;
  final List<File> files;

  MonthlyArchiveEntry({required this.monthKey, required this.files});
}

class DatabaseArchiveService {
  DatabaseArchiveService._();

  static Future<String> createMonthlyArchive({
    required String databaseFilePath,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveRoot = Directory(
      p.join(appDir.path, 'zamzam_erp', 'monthly_archives'),
    );
    final monthKey =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final monthFolder = Directory(p.join(archiveRoot.path, monthKey));

    if (!await monthFolder.exists()) {
      await monthFolder.create(recursive: true);
    }

    final sourceFile = File(databaseFilePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Database file does not exist',
        databaseFilePath,
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final archiveFile = File(
      p.join(monthFolder.path, 'zamzam_erp_${monthKey}_$timestamp.sqlite'),
    );
    await sourceFile.copy(archiveFile.path);

    return archiveFile.path;
  }

  static Future<List<MonthlyArchiveEntry>> listMonthlyArchives() async {
    final appDir = await getApplicationDocumentsDirectory();
    final archiveRoot = Directory(
      p.join(appDir.path, 'zamzam_erp', 'monthly_archives'),
    );

    if (!await archiveRoot.exists()) {
      return [];
    }

    final monthDirs = archiveRoot.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    final entries = <MonthlyArchiveEntry>[];
    for (final monthDir in monthDirs) {
      final files = monthDir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      entries.add(
        MonthlyArchiveEntry(monthKey: p.basename(monthDir.path), files: files),
      );
    }

    return entries;
  }

  static Future<String> createManualArchive() async {
    final appDir = await getApplicationDocumentsDirectory();
    final currentDbFile = File(
      p.join(appDir.path, 'zamzam_erp', 'zamzam_erp.sqlite'),
    );
    if (!await currentDbFile.exists()) {
      throw FileSystemException(
        'Database file does not exist',
        currentDbFile.path,
      );
    }

    return createMonthlyArchive(databaseFilePath: currentDbFile.path);
  }

  static Future<void> restoreArchive({required File archiveFile}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(appDir.path, 'zamzam_erp'));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = File(p.join(targetDir.path, 'zamzam_erp.sqlite'));
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    await archiveFile.copy(targetFile.path);
    await AppDatabase().close();
  }
}
