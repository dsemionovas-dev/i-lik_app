import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islik/core/storage/shared_preferences_provider.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';
import 'package:islik/features/profile/application/profile_controller.dart';
import 'package:islik/features/profile/data/profile_repository.dart';
import 'package:islik/features/profile/domain/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes.dart';

class _FakeProfileRemote implements ProfileRemoteDataSource {
  Profile? stored;
  Object? error;
  final saved = <Profile>[];

  @override
  Future<Profile?> fetch(String userId) async {
    if (error != null) throw error!;
    return stored;
  }

  @override
  Future<void> save(String userId, Profile profile) async {
    if (error != null) throw error!;
    saved.add(profile);
    stored = profile;
  }
}

void main() {
  group('vardas', () {
    test('taisyklės', () {
      for (final ok in ['Žąsinas Jonas', 'Miško_Lapė-7', "O'Neil", 'Ąžuolas']) {
        expect(validateDisplayName(ok), isNull, reason: ok);
      }
      expect(validateDisplayName('Jo'), contains('per trumpas'));
      expect(validateDisplayName('A' * 25), contains('per ilgas'));
      expect(validateDisplayName('jonas@pastas.lt'), isNotNull);
      expect(validateDisplayName('<b>Jonas</b>'), isNotNull);
      expect(validateDisplayName('Jonas  Jonaitis'), contains('kelių tarpų'));
      expect(validateDisplayName('  Jonas  '), isNull, reason: 'kraštiniai tarpai nukerpami');
    });

    test('numatytasis vardas sutampa su serverio (SQL md5)', () {
      // Patikrinta Postgres: upper(substr(md5('1111…'), 1, 5)) = '38C6C'.
      expect(defaultDisplayName('11111111-1111-1111-1111-111111111111'), 'Žygeivis 38C6C');
    });

    test('avataras: nežinomas – numatytasis', () {
      expect(const Profile(avatar: 'owl').avatarEmoji, '🦉');
      expect(const Profile(avatar: 'unicorn').avatarEmoji, avatars[defaultAvatar]!.emoji);
    });
  });

  group('ProfileController', () {
    late ProviderContainer container;
    late _FakeProfileRemote remote;
    late FakeAuthRepository auth;

    Future<void> setUpContainer({bool online = true, Map<String, Object> prefs = const {}}) async {
      SharedPreferences.setMockInitialValues(prefs);
      final sp = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        authRepositoryProvider.overrideWithValue(auth),
        profileRemoteDataSourceProvider.overrideWithValue(online ? remote : null),
      ]);
      addTearDown(container.dispose);
      // Riverpod 3 pristabdo neklausomus providerius – kaip ekranas, klausomės.
      container.listen(profileControllerProvider, (_, _) {});
    }

    ProfileController controller() => container.read(profileControllerProvider.notifier);

    setUp(() {
      remote = _FakeProfileRemote();
      auth = FakeAuthRepository(user: const AppUser(id: 'u1', isAnonymous: true));
    });

    test('be profilio – sugeneruotas vardas', () async {
      await setUpContainer();
      final state = await container.read(profileControllerProvider.future);
      expect(state.displayName, defaultDisplayName('u1'));
    });

    test('išsaugoma serveryje ir įrenginyje; tarpai sutvarkomi', () async {
      await setUpContainer();
      await container.read(profileControllerProvider.future);
      await controller().save(displayName: '  Miško   Lapė ', avatar: 'fox');

      expect(remote.saved.single, const Profile(displayName: 'Miško Lapė', avatar: 'fox'));
      expect(container.read(profileControllerProvider).value!.displayName, 'Miško Lapė');
      final local = LocalProfileStore(container.read(sharedPreferencesProvider)).read('u1');
      expect(local, const Profile(displayName: 'Miško Lapė', avatar: 'fox'));
    });

    test('netinkamas vardas ar avataras – klaida be užklausos', () async {
      await setUpContainer();
      await container.read(profileControllerProvider.future);
      await expectLater(controller().save(displayName: 'J', avatar: 'fox'), throwsA(isA<ProfileFailure>()));
      await expectLater(controller().save(displayName: 'Jonas', avatar: 'unicorn'), throwsA(isA<ProfileFailure>()));
      expect(remote.saved, isEmpty);
    });

    test('be ryšio: rodoma vietinė kopija; išsaugoti nepavyksta – aiški klaida', () async {
      await setUpContainer(prefs: {'profile_u1': jsonEncode({'display_name': 'Vietinis', 'avatar': 'owl'})});
      remote.error = const PostgrestException(message: 'nėra ryšio');

      expect((await container.read(profileControllerProvider.future)).displayName, 'Vietinis');
      await expectLater(
        controller().save(displayName: 'Naujas', avatar: 'owl'),
        throwsA(isA<ProfileFailure>().having((e) => e.message, 'message', contains('interneto ryšį'))),
      );
      expect(container.read(profileControllerProvider).value!.displayName, 'Vietinis');
    });

    test('serverio versija pakeičia vietinę (pakeista kitame įrenginyje)', () async {
      remote.stored = const Profile(displayName: 'Iš serverio', avatar: 'bear');
      await setUpContainer(prefs: {'profile_u1': jsonEncode({'display_name': 'Senas', 'avatar': 'owl'})});
      final state = await container.read(profileControllerProvider.future);
      expect(state.displayName, 'Iš serverio');
      expect(state.profile.avatarEmoji, '🐻');
    });

    test('be Supabase – tik įrenginyje', () async {
      await setUpContainer(online: false);
      await container.read(profileControllerProvider.future);
      await controller().save(displayName: 'Vietinis', avatar: 'deer');
      expect(container.read(profileControllerProvider).value!.profile.avatarEmoji, '🦌');
    });
  });

  test('Supabase: profilis įrašomas upsert į profiles', () async {
    final requests = <http.Request>[];
    final source = SupabaseProfileRemoteDataSource(SupabaseClient(
      'https://test.supabase.co',
      'k',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response('', 201, request: r);
      }),
    ));
    await source.save('u1', const Profile(displayName: 'Miško Lapė', avatar: 'fox'));

    final r = requests.single;
    expect((r.method, r.url.path), ('POST', '/rest/v1/profiles'));
    expect(r.headers['Prefer'], contains('resolution=merge-duplicates'));
    expect(jsonDecode(r.body), {'user_id': 'u1', 'display_name': 'Miško Lapė', 'avatar': 'fox'});
  });
}
