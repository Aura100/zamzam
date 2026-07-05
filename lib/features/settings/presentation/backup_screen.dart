import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_layout.dart';

final lastBackupTimeProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('last_backup_time');
});

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;

  Future<File> _getDbFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'zamzam_erp', 'zamzam_erp.sqlite'));
  }

  Future<void> _takeBackup() async {
    setState(() => _isLoading = true);
    try {
      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        _showSnack('❌ لم يتم العثور على قاعدة البيانات', Colors.red);
        return;
      }

      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
      final suggestedName = 'zamzam_backup_$dateStr.sqlite';

      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'SQLite Database', extensions: ['sqlite', 'db']),
        ],
      );

      if (saveLocation == null) return;

      await dbFile.copy(saveLocation.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_backup_time', now.toIso8601String());

      ref.invalidate(lastBackupTimeProvider);
      _showSnack('✅ تم حفظ النسخة الاحتياطية بنجاح', Colors.green);
    } catch (e) {
      _showSnack('❌ خطأ في النسخ الاحتياطي: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ تحذير مهم'),
        content: const Text(
          'سيتم استبدال جميع البيانات الحالية بالبيانات من الملف المختار.\n\nهذه العملية لا يمكن التراجع عنها!\n\nهل أنت متأكد؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، استعادة البيانات', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'SQLite Database',
        extensions: ['sqlite', 'db'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) return;

      final dbFile = await _getDbFile();
      final backupBeforeRestore = '${dbFile.path}.backup_before_restore';
      if (await dbFile.exists()) {
        await dbFile.copy(backupBeforeRestore);
      }

      final bytes = await file.readAsBytes();
      await dbFile.writeAsBytes(bytes);

      _showSnack('✅ تمت الاستعادة. يرجى إعادة تشغيل التطبيق لتفعيل البيانات.', Colors.green);
    } catch (e) {
      _showSnack('❌ خطأ في الاستعادة: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastBackupAsync = ref.watch(lastBackupTimeProvider);

    return AppLayout(
      title: 'النسخ الاحتياطي',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade400],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.white, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'النسخ الاحتياطي وحماية البيانات',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  lastBackupAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (time) {
                      if (time == null) {
                        return const Text('لم يتم أخذ نسخة احتياطية بعد', style: TextStyle(color: Colors.white70));
                      }
                      final dt = DateTime.tryParse(time);
                      if (dt == null) return const SizedBox.shrink();
                      return Text(
                        'آخر نسخة: ${DateFormat('yyyy/MM/dd - hh:mm a').format(dt)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_isLoading)
              const Center(child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('جاري المعالجة...'),
                ],
              ))
            else ...[
              // Backup Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.download, color: Colors.green.shade700, size: 36),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('أخذ نسخة احتياطية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              'احفظ نسخة من جميع بياناتك (العملاء، المبيعات، المخزون) على جهازك أو OneDrive أو Google Drive.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _takeBackup,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('نسخ الآن'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Restore Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.restore, color: Colors.orange.shade700, size: 36),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('استعادة من نسخة سابقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              'قم باستعادة بيانات نسخة احتياطية سابقة. تحذير: سيتم حذف البيانات الحالية.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _restoreBackup,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('استعادة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tips
              Card(
                color: Colors.blue.shade50,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text('نصائح مهمة للحفاظ على بياناتك', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _tip('احتفظ بنسخة احتياطية يومية على الأقل'),
                      _tip('احفظ النسخ في مجلد OneDrive أو Google Drive لحمايتها سحابياً'),
                      _tip('احتفظ بأكثر من نسخة بتواريخ مختلفة'),
                      _tip('بعد الاستعادة، أعد تشغيل التطبيق لتطبيق التغييرات'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
