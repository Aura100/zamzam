import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class MaintenanceRepository {
  final AppDatabase _db;

  MaintenanceRepository(this._db);

  Stream<List<MaintenanceRequest>> watchAllRequests() {
    return _db.select(_db.maintenanceRequests).watch();
  }

  Future<void> createRequest(MaintenanceRequestsCompanion request) async {
    await _db.into(_db.maintenanceRequests).insert(request);
  }

  Future<void> assignTechnician(int requestId, int technicianId) async {
    await (_db.update(_db.maintenanceRequests)..where((t) => t.id.equals(requestId))).write(
      MaintenanceRequestsCompanion(
        technicianId: Value(technicianId),
        status: const Value('InProgress'),
      ),
    );
  }

  Future<void> dispensePart(int requestId, int productId, int quantity, int userId) async {
    await _db.transaction(() async {
      // 1. Get product to check stock and price
      final product = await (_db.select(_db.products)..where((t) => t.id.equals(productId))).getSingle();
      
      // 2. Insert into MaintenanceParts
      await _db.into(_db.maintenanceParts).insert(
        MaintenancePartsCompanion.insert(
          requestId: requestId,
          productId: productId,
          quantityOut: Value(quantity),
          unitPrice: Value(product.cashPrice),
        ),
      );

      // 3. Check if there is an assigned technician to deduct from custody
      final request = await (_db.select(_db.maintenanceRequests)..where((t) => t.id.equals(requestId))).getSingle();
      if (request.technicianId != null) {
        final custody = await (_db.select(_db.technicianCustody)
              ..where((t) => t.technicianId.equals(request.technicianId!) & t.productId.equals(productId)))
            .getSingleOrNull();

        final custodyQty = custody?.quantity ?? 0;
        if (custodyQty >= quantity) {
          // Deduct fully from custody
          await (_db.update(_db.technicianCustody)..where((t) => t.id.equals(custody!.id))).write(
            TechnicianCustodyCompanion(quantity: Value(custodyQty - quantity)),
          );
          // Log Custody movement
          await _db.into(_db.inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              productId: productId,
              type: 'OUT_CUSTODY_USE',
              quantity: quantity,
              referenceId: Value('MNT-$requestId'),
              notes: Value('استخدام من عهدة الفني لطلب صيانة #$requestId'),
              createdBy: Value(userId),
            ),
          );
          return;
        } else {
          // Deduct whatever is in custody, and the rest from main stock
          final remaining = quantity - custodyQty;
          if (custodyQty > 0) {
            await (_db.update(_db.technicianCustody)..where((t) => t.id.equals(custody!.id))).write(
              TechnicianCustodyCompanion(quantity: const Value(0)),
            );
            await _db.into(_db.inventoryMovements).insert(
              InventoryMovementsCompanion.insert(
                productId: productId,
                type: 'OUT_CUSTODY_USE',
                quantity: custodyQty,
                referenceId: Value('MNT-$requestId'),
                notes: Value('استخدام جزء من عهدة الفني لطلب صيانة #$requestId'),
                createdBy: Value(userId),
              ),
            );
          }
          // Deduct remaining from main stock
          await (_db.update(_db.products)..where((t) => t.id.equals(productId))).write(
            ProductsCompanion(
              currentStock: Value(product.currentStock - remaining),
            ),
          );
          await _db.into(_db.inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              productId: productId,
              type: 'OUT',
              quantity: remaining,
              referenceId: Value('MNT-$requestId'),
              notes: Value('صرف عجز العهدة من المخزن الرئيسي لطلب صيانة #$requestId'),
              createdBy: Value(userId),
            ),
          );
          return;
        }
      }

      // 4. Fallback/Default: Deduct from Main Stock
      await _db.into(_db.inventoryMovements).insert(
        InventoryMovementsCompanion.insert(
          productId: productId,
          type: 'OUT',
          quantity: quantity,
          referenceId: Value('MNT-$requestId'),
          notes: Value('صرف قطع لطلب صيانة #$requestId'),
          createdBy: Value(userId),
        ),
      );

      await (_db.update(_db.products)..where((t) => t.id.equals(productId))).write(
        ProductsCompanion(
          currentStock: Value(product.currentStock - quantity),
        ),
      );
    });
  }

  Future<List<MaintenancePart>> getPartsForRequest(int requestId) {
    return (_db.select(_db.maintenanceParts)..where((t) => t.requestId.equals(requestId))).get();
  }

  Future<void> completeRequest(int id, double serviceCost, String notes, Map<int, int> actualUsedQuantities, int userId) async {
    await _db.transaction(() async {
      final parts = await getPartsForRequest(id);
      double totalPartsCost = 0.0;

      for (final part in parts) {
        final usedQty = actualUsedQuantities[part.id] ?? part.quantityOut;
        final returnedQty = part.quantityOut - usedQty;
        totalPartsCost += (usedQty * part.unitPrice);

        // Update the part record
        await (_db.update(_db.maintenanceParts)..where((t) => t.id.equals(part.id))).write(
          MaintenancePartsCompanion(
            quantityUsed: Value(usedQty),
          ),
        );

        // If some parts were returned, add them back to technician custody or main inventory
        if (returnedQty > 0) {
          final request = await (_db.select(_db.maintenanceRequests)..where((t) => t.id.equals(id))).getSingle();
          if (request.technicianId != null) {
            final custody = await (_db.select(_db.technicianCustody)
                  ..where((t) => t.technicianId.equals(request.technicianId!) & t.productId.equals(part.productId)))
                .getSingleOrNull();

            if (custody != null) {
              await (_db.update(_db.technicianCustody)..where((t) => t.id.equals(custody.id))).write(
                TechnicianCustodyCompanion(quantity: Value(custody.quantity + returnedQty)),
              );
            } else {
              await _db.into(_db.technicianCustody).insert(
                TechnicianCustodyCompanion.insert(
                  technicianId: request.technicianId!,
                  productId: part.productId,
                  quantity: Value(returnedQty),
                ),
              );
            }

            await _db.into(_db.inventoryMovements).insert(
              InventoryMovementsCompanion.insert(
                productId: part.productId,
                type: 'IN_CUSTODY_RETURN',
                quantity: returnedQty,
                referenceId: Value('MNT-$id-RET'),
                notes: Value('مرتجعات لعهدة الفني من طلب صيانة #$id'),
                createdBy: Value(userId),
              ),
            );
          } else {
            await _db.into(_db.inventoryMovements).insert(
              InventoryMovementsCompanion.insert(
                productId: part.productId,
                type: 'IN',
                quantity: returnedQty,
                referenceId: Value('MNT-$id-RET'),
                notes: Value('مرتجعات من طلب صيانة #$id'),
                createdBy: Value(userId),
              ),
            );

            final product = await (_db.select(_db.products)..where((t) => t.id.equals(part.productId))).getSingle();
            await (_db.update(_db.products)..where((t) => t.id.equals(product.id))).write(
              ProductsCompanion(
                currentStock: Value(product.currentStock + returnedQty),
              ),
            );
          }
        }
      }

      // Finally, complete the request
      await (_db.update(_db.maintenanceRequests)..where((t) => t.id.equals(id))).write(
        MaintenanceRequestsCompanion(
          status: const Value('Completed'),
          completionDate: Value(DateTime.now()),
          cost: Value(serviceCost + totalPartsCost),
          notes: Value(notes),
        ),
      );
    });
  }
}
