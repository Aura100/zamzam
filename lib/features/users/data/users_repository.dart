import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';

class UsersRepository {
  final AppDatabase _db;
  UsersRepository(this._db);

  Stream<List<User>> watchAllUsers() =>
      (_db.select(_db.users)..where((t) => t.isDeleted.equals(false))).watch();

  Future<void> addUser(UsersCompanion user) async {
    await _db.into(_db.users).insert(user);
  }

  Future<void> updateUserPin(int userId, String newPin) async {
    await (_db.update(_db.users)..where((t) => t.id.equals(userId)))
        .write(UsersCompanion(pinCode: Value(newPin)));
  }

  Future<void> deleteUser(int id) async {
    await (_db.update(_db.users)..where((t) => t.id.equals(id)))
        .write(UsersCompanion(isDeleted: const Value(true)));
  }

  Stream<List<User>> watchTechnicians() =>
      (_db.select(_db.users)..where((t) => t.isDeleted.equals(false) & t.role.equals('Technician'))).watch();
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(databaseProvider));
});

final usersStreamProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(usersRepositoryProvider).watchAllUsers();
});

final techniciansStreamProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(usersRepositoryProvider).watchTechnicians();
});
