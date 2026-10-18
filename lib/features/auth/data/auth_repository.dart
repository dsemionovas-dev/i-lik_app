import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../../core/storage/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/app_user.dart';

abstract interface class AuthRepository {
  /// `false` – tik vietinis svečias (Supabase nesukonfigūruotas).
  bool get supportsAccounts;

  AppUser? get currentUser;

  /// Dabartinis vartotojas, tada kiekvienas pokytis.
  Stream<AppUser?> authStateChanges();

  /// Grąžina esamą vartotoją arba sukuria svečią (PRD: svečio režimas).
  Future<AppUser> ensureSignedIn();

  Future<AppUser> signInWithEmail(String email, String password);

  /// `true`, jei reikia patvirtinti el. paštą prieš prisijungiant.
  Future<bool> signUpWithEmail(String email, String password);

  /// Svečią paverčia nuolatine paskyra (tas pats ID – progresas išlieka).
  /// Supabase išsiunčia patvirtinimo laišką.
  Future<void> linkEmail(String email);

  /// Nustato (ar pakeičia) slaptažodį prisijungusiam vartotojui.
  Future<void> setPassword(String password);

  /// Atnaujina vartotojo duomenis iš serverio (pvz., el. paštas patvirtintas naršyklėje).
  Future<void> refreshUser();

  /// Išsiunčia slaptažodžio atstatymo laišką (su kodu ir nuoroda). Neatskleidžia,
  /// ar paskyra su tokiu el. paštu yra.
  Future<void> sendPasswordReset(String email);

  /// Patikrina laiške gautą kodą ir prisijungia – po to galima [setPassword].
  Future<AppUser> verifyPasswordResetCode(String email, String code);

  /// Vartotojas atidarė atstatymo nuorodą iš laiško (gilioji nuoroda) – jau prisijungęs,
  /// reikia tik naujo slaptažodžio.
  Stream<void> passwordRecoveryEvents();

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  bool get supportsAccounts => true;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  /// `user_metadata` žyma, kad slaptažodis nustatytas – Supabase to neatskleidžia.
  static const passwordSetFlag = 'password_set';

  static AppUser? _map(User? user) => user == null
      ? null
      : AppUser(
          id: user.id,
          email: user.email,
          isAnonymous: user.isAnonymous,
          pendingEmail: user.newEmail,
          needsPassword: !user.isAnonymous &&
              user.email != null &&
              user.emailConfirmedAt != null &&
              user.userMetadata?[passwordSetFlag] != true,
        );

  @override
  Stream<AppUser?> authStateChanges() {
    // Ne `async*`: jo atšaukimas laukia gotrue prenumeratos atšaukimo, kuris
    // niekada nesibaigia – atsijungęs klausytojas užstrigtų.
    late final StreamController<AppUser?> controller;
    StreamSubscription<AuthState>? subscription;
    controller = StreamController<AppUser?>(
      onListen: () {
        var last = currentUser;
        controller.add(last);
        subscription = _auth.onAuthStateChange.listen(
          (state) {
            final user = _map(state.session?.user);
            if (user != last) controller.add(last = user);
          },
          onError: controller.addError,
        );
      },
      onCancel: () => unawaited(subscription?.cancel()),
    );
    return controller.stream;
  }

  @override
  Future<AppUser> ensureSignedIn() async {
    final existing = currentUser;
    if (existing != null) return existing;
    final response = await _guard(_auth.signInAnonymously);
    return _map(response.user)!;
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final response = await _guard(() => _auth.signInWithPassword(email: email.trim(), password: password));
    final user = response.user!;
    // Prisijungė slaptažodžiu – vadinasi, jį turi (pvz., paskyra sukurta anksčiau).
    if (user.userMetadata?[passwordSetFlag] != true) {
      try {
        await _auth.updateUser(UserAttributes(data: {passwordSetFlag: true}));
      } catch (_) {
        // Tik UI žyma – nepavykus, prisijungimas vis tiek sėkmingas.
      }
    }
    return currentUser ?? _map(user)!;
  }

  @override
  Future<bool> signUpWithEmail(String email, String password) async {
    final response = await _guard(
      () => _auth.signUp(email: email.trim(), password: password, data: {passwordSetFlag: true}),
    );
    return response.session == null;
  }

  @override
  Future<void> linkEmail(String email) async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      throw const AuthFailure('Susieti galima tik svečio paskyrą.');
    }
    await _guard(() => _auth.updateUser(UserAttributes(email: email.trim())));
  }

  @override
  Future<void> setPassword(String password) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthFailure('Pirmiausia susiekite ir patvirtinkite el. paštą.');
    }
    await _guard(() => _auth.updateUser(UserAttributes(password: password, data: {passwordSetFlag: true})));
  }

  @override
  Future<void> refreshUser() async {
    if (_auth.currentSession == null) return;
    await _guard(_auth.refreshSession);
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim(), redirectTo: Env.authRedirectUrl));

  @override
  Future<AppUser> verifyPasswordResetCode(String email, String code) async {
    final response = await _guard(
      () => _auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.recovery),
    );
    return _map(response.user)!;
  }

  @override
  Stream<void> passwordRecoveryEvents() =>
      _auth.onAuthStateChange.where((s) => s.event == AuthChangeEvent.passwordRecovery).map((_) {});

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AuthFailure(describeAuthError(e));
    } on SocketException {
      throw const AuthFailure('Nėra interneto ryšio. Pabandykite vėliau.');
    } on TimeoutException {
      throw const AuthFailure('Serveris neatsako. Pabandykite vėliau.');
    }
  }
}

/// Supabase Auth klaidų kodai → lietuviški pranešimai.
String describeAuthError(AuthException e) => switch (e.code) {
      'invalid_credentials' => 'Neteisingas el. paštas arba slaptažodis.',
      'email_not_confirmed' => 'Pirmiausia patvirtinkite el. paštą – nuoroda išsiųsta laišku.',
      'user_already_exists' || 'email_exists' => 'Paskyra su šiuo el. paštu jau yra. Prisijunkite.',
      'weak_password' => 'Slaptažodis per silpnas – naudokite bent 8 simbolius su raidėmis ir skaičiais.',
      'same_password' => 'Naujas slaptažodis turi skirtis nuo dabartinio.',
      'reauthentication_needed' => 'Dėl saugumo prisijunkite iš naujo ir pakartokite.',
      'otp_expired' => 'Kodas neteisingas arba nebegalioja. Paprašykite naujo.',
      'validation_failed' || 'email_address_invalid' => 'Neteisingas el. pašto adresas.',
      'over_request_rate_limit' || 'over_email_send_rate_limit' => 'Per daug bandymų. Palaukite kelias minutes.',
      'anonymous_provider_disabled' => 'Svečio režimas serveryje išjungtas.',
      _ => 'Nepavyko: ${e.message}',
    };

/// Be Supabase: svečias su vietiniu ID (kūrimui ir demonstracijai).
class LocalGuestAuthRepository implements AuthRepository {
  LocalGuestAuthRepository(this._prefs, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  static const _key = 'local_guest_id';

  final SharedPreferences _prefs;
  final Uuid _uuid;
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  bool get supportsAccounts => false;

  @override
  AppUser? get currentUser {
    final id = _prefs.getString(_key);
    return id == null ? null : AppUser(id: id, isAnonymous: true);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }

  @override
  Future<AppUser> ensureSignedIn() async {
    final existing = currentUser;
    if (existing != null) return existing;
    await _prefs.setString(_key, _uuid.v4());
    _changes.add(currentUser);
    return currentUser!;
  }

  static const _unavailable = AuthFailure('Paskyros šioje versijoje nepasiekiamos (serveris nesukonfigūruotas).');

  @override
  Future<AppUser> signInWithEmail(String email, String password) async => throw _unavailable;

  @override
  Future<bool> signUpWithEmail(String email, String password) async => throw _unavailable;

  @override
  Future<void> linkEmail(String email) async => throw _unavailable;

  @override
  Future<void> setPassword(String password) async => throw _unavailable;

  @override
  Future<void> refreshUser() async {}

  @override
  Future<void> sendPasswordReset(String email) async => throw _unavailable;

  @override
  Future<AppUser> verifyPasswordResetCode(String email, String code) async => throw _unavailable;

  @override
  Stream<void> passwordRecoveryEvents() => const Stream.empty();

  @override
  Future<void> signOut() async {
    await _prefs.remove(_key);
    _changes.add(null);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? LocalGuestAuthRepository(ref.watch(sharedPreferencesProvider))
      : SupabaseAuthRepository(client.auth);
});

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Atidaryta slaptažodžio atstatymo nuoroda – app'as nukreipia į naujo slaptažodžio ekraną.
/// Skaitiklis, kad kiekvienas įvykis būtų nauja reikšmė (klausytojai jį pastebi).
final passwordRecoveryProvider = StreamProvider<int>((ref) {
  var count = 0;
  return ref.watch(authRepositoryProvider).passwordRecoveryEvents().map((_) => ++count);
});
