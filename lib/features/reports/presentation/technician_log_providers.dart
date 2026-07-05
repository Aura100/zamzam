import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import 'package:drift/drift.dart';

// Provides completed maintenance requests for a given technician
final technicianCompletedRequestsProvider = FutureProvider.family<List<MaintenanceRequest>, int>((ref, technicianId) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.maintenanceRequests)
    ..where((t) => t.technicianId.equals(technicianId) & t.status.equals('Completed'))
    ..orderBy([(t) => OrderingTerm(expression: t.completionDate, mode: OrderingMode.desc)]))
  .get();
});

// Provides all payments/handovers made by a given technician
final technicianPaymentsProvider = FutureProvider.family<List<MaintenancePayment>, int>((ref, technicianId) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.maintenancePayments)
    ..where((t) => t.technicianId.equals(technicianId))
    ..orderBy([(t) => OrderingTerm(expression: t.paymentDate, mode: OrderingMode.desc)]))
  .get();
});

// Provides the inventory movements (dispense/return) associated with a given technician
// We filter by notes containing the technician ID as a simple heuristic since we don't have a direct relation in InventoryMovements
final technicianMovementsProvider = FutureProvider.family<List<InventoryMovement>, int>((ref, technicianId) async {
  final db = ref.watch(databaseProvider);
  final allMovements = await (db.select(db.inventoryMovements)
    ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
  .get();

  return allMovements.where((m) => 
    (m.notes ?? '').contains('فني رقم $technicianId') || 
    (m.notes ?? '').contains('الفني رقم $technicianId')
  ).toList();
});

// Provides current custody for a given technician
final technicianCurrentCustodyProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, technicianId) async {
  final db = ref.watch(databaseProvider);
  final items = await (db.select(db.technicianCustody)..where((t) => t.technicianId.equals(technicianId))).get();
  
  List<Map<String, dynamic>> result = [];
  for (var item in items) {
    final product = await (db.select(db.products)..where((t) => t.id.equals(item.productId))).getSingle();
    result.add({
      'custody': item,
      'product': product,
    });
  }
  return result;
});
