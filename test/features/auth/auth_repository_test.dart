import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _guestId = '7f1c2a3b-0000-4000-8000-000000000001';

/// Kaip tikras Supabase serveris: nuo jos priklauso, iš kurio lauko skaitomas klaidos kodas.
const _apiHeaders = {'content-type': 'application/json', 'x-supabase-api-version': '2024-01-01'};

/// PKCE srautui (el. pašto keitimas) – programėlėje ją suteikia Supabase.initialize.
class _MemoryStorage extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

/// Supabase Auth atsakymas su sesija.
Map<String, Object?> _session({required bool anonymous, String? email}) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  return {
    'access_token': '${b64({'alg': 'HS256'})}.${b64({'sub': _guestId, 'exp': exp, 'role': 'authenticated'})}.sig',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'refresh_token': 'refresh',
    'user': {
      'id': _guestId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'is_anonymous': anonymous,
      'app_metadata': <String, Object>{},
      'user_metadata': <String, Object>{},
      'created_at': '2026-10-18T09:00:00Z',
    },
  };
}

void main() {
  group('SupabaseAuthRepository', () {
    late List<http.Request> requests;
    late http.Response Function(http.Request) respond;
    late SupabaseAuthRepository repo;

    http.Response json(http.Request r, Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          headers: _apiHeaders,
          request: r,
        );

    setUp(() {
      requests = [];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'publishable-key',
        httpClient: MockClient((r) async {
          requests.add(r);
          return respond(r);
        }),
        authOptions: AuthClientOptions(autoRefreshToken: false, pkceAsyncStorage: _MemoryStorage()),
      );
      repo = SupabaseAuthRepository(client.auth);
    });

    test('svečias: anoniminis prisijungimas tik kai sesijos nėra', () async {
      respond = (r) => json(r, _session(anonymous: true));
      expect(repo.currentUser, isNull);

      final user = await repo.ensureSignedIn();
      expect(user, const AppUser(id: _guestId, isAnonymous: true));
      expect(requests.single.url.path, '/auth/v1/signup');

      await repo.ensureSignedIn();
      expect(requests, hasLength(1), reason: 'antrą kartą – esamas vartotojas');
    });

    test('authStateChanges: dabartinis, tada pokyčiai', () async {
      respond = (r) => json(r, _session(anonymous: true));
      final events = <AppUser?>[];
      final sub = repo.authStateChanges().listen(events.add);
      await pumpEventQueue();

      await repo.ensureSignedIn();
      await pumpEventQueue();
      respond = (r) => http.Response('', 204, request: r);
      await repo.signOut();
      await pumpEventQueue();
      await sub.cancel();

      expect(events, [null, const AppUser(id: _guestId, isAnonymous: true), null]);
    });

    test('svečio susiejimas su el. paštu – PUT /user su tuo pačiu vartotoju', () async {
      respond = (r) => json(r, _session(anonymous: true));
      await repo.ensureSignedIn();

      respond = (r) => json(r, {...(_session(anonymous: true)['user']! as Map<String, Object?>), 'new_email': 'jonas@pastas.lt'});
      await repo.linkEmail(' jonas@pastas.lt ');

      final put = requests.last;
      expect(put.method, 'PUT');
      expect(put.url.path, '/auth/v1/user');
      expect((jsonDecode(put.body) as Map<String, dynamic>)['email'], 'jonas@pastas.lt');
      expect(put.headers['Authorization'], startsWith('Bearer '));
    });

    test('susieti galima tik svečią', () async {
      expect(repo.linkEmail('a@b.lt'), throwsA(isA<AuthFailure>()));
    });

    test('prisijungimas el. paštu', () async {
      respond = (r) => json(r, _session(anonymous: false, email: 'jonas@pastas.lt'));
      final user = await repo.signInWithEmail('jonas@pastas.lt', 'slaptazodis');

      expect(user.email, 'jonas@pastas.lt');
      expect(user.isAnonymous, isFalse);
      expect(requests.single.url.path, '/auth/v1/token');
      expect(requests.single.url.queryParameters['grant_type'], 'password');
    });

    test('registracija su patvirtinimu – sesijos nėra', () async {
      respond = (r) => json(r, _session(anonymous: false, email: 'nauja@pastas.lt')['user']!);
      expect(await repo.signUpWithEmail('nauja@pastas.lt', 'slaptazodis'), isTrue);
    });

    test('Supabase klaidos kodai → lietuviški pranešimai', () async {
      respond = (r) => json(r, {'code': 'invalid_credentials', 'msg': 'Invalid login credentials'}, 400);
      expect(
        repo.signInWithEmail('jonas@pastas.lt', 'blogas123'),
        throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'Neteisingas el. paštas arba slaptažodis.')),
      );
    });
  });

  group('LocalGuestAuthRepository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('svečio ID sukuriamas vieną kartą ir išlieka', () async {
      final repo = LocalGuestAuthRepository(prefs);
      expect(repo.supportsAccounts, isFalse);
      expect(repo.currentUser, isNull);

      final a = await repo.ensureSignedIn();
      final b = await LocalGuestAuthRepository(prefs).ensureSignedIn();
      expect(a.isAnonymous, isTrue);
      expect(b.id, a.id, reason: 'naujas egzempliorius (perkrovimas) – tas pats ID');
    });

    test('pokyčiai transliuojami; atsijungus – null', () async {
      final repo = LocalGuestAuthRepository(prefs);
      final events = <AppUser?>[];
      final sub = repo.authStateChanges().listen(events.add);
      await pumpEventQueue();
      final user = await repo.ensureSignedIn();
      await repo.signOut();
      await pumpEventQueue();
      await sub.cancel();

      expect(events, [null, user, null]);
    });

    test('el. pašto veiksmai nepasiekiami', () async {
      final repo = LocalGuestAuthRepository(prefs);
      await expectLater(repo.signInWithEmail('a@b.lt', '12345678'), throwsA(isA<AuthFailure>()));
      await expectLater(repo.linkEmail('a@b.lt'), throwsA(isA<AuthFailure>()));
    });
  });
}
