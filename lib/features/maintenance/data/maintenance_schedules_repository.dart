import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class MaintenanceSchedulesRepository {
  final AppDatabase _db;

  MaintenanceSchedulesRepository(this._db);

  Stream<List<MaintenanceSchedule>> watchAllSchedules() {
    return _db.select(_db.maintenanceSchedules).watch();
  }

  Future<void> addSchedule(MaintenanceSchedulesCompanion schedule) async {
    await _db.into(_db.maintenanceSchedules).insert(schedule);
  }

  Future<void> postponeSchedule(int scheduleId, DateTime postponeUntil) async {
    await (_db.update(_db.maintenanceSchedules)..where((t) => t.id.equals(scheduleId))).write(
      MaintenanceSchedulesCompanion(
        status: const Value('Postponed'),
        postponedUntil: Value(postponeUntil),
      ),
    );
  }

  Future<void> createRequestFromSchedule(int scheduleId, MaintenanceRequestsCompanion request) async {
    await _db.transaction(() async {
      // 1. Create the Maintenance Request
      await _db.into(_db.maintenanceRequests).insert(request);

      // 2. Update the Schedule
      final schedule = await (_db.select(_db.maintenanceSchedules)..where((t) => t.id.equals(scheduleId))).getSingle();
      
      final now = DateTime.now();
      // Calculate next date based on cycle
      int monthsToAdd = schedule.cycleMonths;
      DateTime nextDate = DateTime(now.year, now.month + monthsToAdd, now.day);

      await (_db.update(_db.maintenanceSchedules)..where((t) => t.id.equals(scheduleId))).write(
        MaintenanceSchedulesCompanion(
          lastMaintenanceDate: Value(now),
          nextMaintenanceDate: Value(nextDate),
          status: const Value('Active'),
          postponedUntil: const Value(null),
        ),
      );
    });
  }

  Future<void> deleteSchedule(int id) async {
     await (_db.delete(_db.maintenanceSchedules)..where((t) => t.id.equals(id))).go();
  }
}
