import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class AuthRepository {
  final AppDatabase _db;

  AuthRepository(this._db);

  Future<User?> login(String pinCode) async {
    final query = _db.select(_db.users)..where((t) => t.pinCode.equals(pinCode));
    return await query.getSingleOrNull();
  }

  Future<void> changePin(int userId, String newPin) async {
    await (_db.update(_db.users)..where((t) => t.id.equals(userId)))
        .write(UsersCompanion(pinCode: Value(newPin)));
  }
}
