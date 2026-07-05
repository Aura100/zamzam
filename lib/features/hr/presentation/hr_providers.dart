import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final employeeProfilesProvider = FutureProvider<List<EmployeeProfile>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.select(db.employeeProfiles).get();
});

final employeeWithUserProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  final query = db.select(db.employeeProfiles).join([
    drift.innerJoin(db.users, db.users.id.equalsExp(db.employeeProfiles.userId)),
  ]);
  
  final results = await query.get();
  
  return results.map((row) {
    return {
      'profile': row.readTable(db.employeeProfiles),
      'user': row.readTable(db.users),
    };
  }).toList();
});

final hrRepositoryProvider = Provider((ref) => HRRepository(ref.watch(databaseProvider)));

class HRRepository {
  final AppDatabase db;
  HRRepository(this.db);

  Future<void> createOrUpdateProfile(EmployeeProfilesCompanion profile) async {
    await db.into(db.employeeProfiles).insertOnConflictUpdate(profile);
  }

  Future<void> addTransaction(PayrollTransactionsCompanion transaction) async {
    await db.into(db.payrollTransactions).insert(transaction);
  }

  Future<List<PayrollTransaction>> getUnprocessedTransactions(int employeeId) async {
    return (db.select(db.payrollTransactions)
          ..where((t) => t.employeeId.equals(employeeId))
          ..where((t) => t.processedInPayrollId.isNull()))
        .get();
  }

  Future<void> closePayrollForMonth(String monthYear) async {
    await db.transaction(() async {
      final profiles = await db.select(db.employeeProfiles).get();
      for (final profile in profiles) {
        if (profile.status != 'Active') continue;
        
        final transactions = await getUnprocessedTransactions(profile.id);
        
        double totalBonuses = 0.0;
        double totalDeductions = 0.0; // Includes deductions and advances
        
        for (final t in transactions) {
          if (t.type == 'BONUS') {
            totalBonuses += t.amount;
          } else {
            totalDeductions += t.amount;
          }
        }
        
        final netSalary = profile.baseSalary + totalBonuses - totalDeductions;
        
        final payrollId = await db.into(db.monthlyPayrolls).insert(
          MonthlyPayrollsCompanion.insert(
            employeeId: profile.id,
            monthYear: monthYear,
            baseSalary: profile.baseSalary,
            totalBonuses: totalBonuses,
            totalDeductions: totalDeductions,
            netSalary: netSalary,
          )
        );
        
        if (transactions.isNotEmpty) {
          await (db.update(db.payrollTransactions)
                ..where((t) => t.employeeId.equals(profile.id))
                ..where((t) => t.processedInPayrollId.isNull()))
              .write(PayrollTransactionsCompanion(processedInPayrollId: drift.Value(payrollId)));
        }
      }
    });
  }
}
