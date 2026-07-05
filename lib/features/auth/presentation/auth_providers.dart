import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthRepository(db);
});

final currentUserProvider = StateProvider<User?>((ref) => null);

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repository;
  final StateController<User?> _currentUserController;

  AuthNotifier(this._repository, this._currentUserController)
      : super(const AsyncValue.data(null));

  Future<bool> login(String pinCode) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(pinCode);
      if (user != null) {
        _currentUserController.state = user;
        state = AsyncValue.data(user);
        return true;
      } else {
        state = AsyncValue.error('رمز المرور غير صحيح', StackTrace.current);
        return false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void logout() {
    _currentUserController.state = null;
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(currentUserProvider.notifier),
  );
});
