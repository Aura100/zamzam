import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class ExpensesRepository {
  final AppDatabase _db;

  ExpensesRepository(this._db);

  Stream<List<Expense>> watchAllExpenses() {
    return (_db.select(_db.expenses)
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> addExpense(ExpensesCompanion expense) async {
    await _db.into(_db.expenses).insert(expense);
  }
}
