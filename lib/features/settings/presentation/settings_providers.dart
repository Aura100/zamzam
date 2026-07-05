import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

final companySettingsProvider = FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final settings = await db.select(db.companySettings).get();
  
  return {
    for (var s in settings) s.key: s.value,
  };
});
