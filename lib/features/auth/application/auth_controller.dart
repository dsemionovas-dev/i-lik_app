import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Prisijungimo veiksmai UI: `state` – vykdomas veiksmas (loading) arba klaida.
/// Pats vartotojas – [authStateProvider].
class AuthController extends AsyncNotifier<String?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// `state.value` – sėkmės pranešimas vartotojui (pvz., „Patikrinkite paštą“).
  @override
  Future<String?> build() async => null;

  Future<bool> signIn(String email, String password) =>
      _run(() async {
        _validate(email, password);
        await _repo.signInWithEmail(email, password);
        return null;
      });

  Future<bool> signUp(String email, String password) =>
      _run(() async {
        _validate(email, password);
        final needsConfirmation = await _repo.signUpWithEmail(email, password);
        return needsConfirmation ? 'Patvirtinkite el. paštą – nuoroda išsiųsta laišku.' : null;
      });

  Future<bool> linkEmail(String email) =>
      _run(() async {
        _validateEmail(email);
        await _repo.linkEmail(email);
        return 'Patvirtinkite el. paštą – po to galėsite prisijungti bet kuriame įrenginyje.';
      });

  Future<bool> signOut() => _run(() async {
        await _repo.signOut();
        return null;
      });

  Future<bool> _run(Future<String?> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static void _validateEmail(String email) {
    if (!_emailPattern.hasMatch(email.trim())) throw const AuthFailure('Neteisingas el. pašto adresas.');
  }

  static void _validate(String email, String password) {
    _validateEmail(email);
    if (password.length < 8) throw const AuthFailure('Slaptažodis turi būti bent 8 simbolių.');
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, String?>(AuthController.new);
