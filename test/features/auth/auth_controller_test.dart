import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/auth/application/auth_controller.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  AuthController controller() => container.read(authControllerProvider.notifier);
  AsyncValue<String?> state() => container.read(authControllerProvider);

  setUp(() {
    repo = FakeAuthRepository(user: const AppUser(id: 'guest-1', isAnonymous: true));
    container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repo)]);
    container.listen(authControllerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('neteisingas el. paštas ir trumpas slaptažodis atmetami be užklausos', () async {
    expect(await controller().signIn('ne-pastas', 'slaptazodis'), isFalse);
    expect(state().error.toString(), 'Neteisingas el. pašto adresas.');

    expect(await controller().signIn('jonas@pastas.lt', '123'), isFalse);
    expect(state().error.toString(), 'Slaptažodis turi būti bent 8 simbolių.');
    expect(repo.calls, isEmpty);
  });

  test('prisijungimas', () async {
    expect(await controller().signIn('jonas@pastas.lt', 'slaptazodis'), isTrue);
    expect(state(), const AsyncData<String?>(null));
    expect(repo.currentUser!.email, 'jonas@pastas.lt');
  });

  test('susiejimas – pranešimas patikrinti paštą', () async {
    expect(await controller().linkEmail('jonas@pastas.lt'), isTrue);
    expect(state().value, contains('Patvirtinkite el. paštą'));
    expect(repo.calls, ['link:jonas@pastas.lt']);
  });

  test('registracija, kai reikia patvirtinimo', () async {
    expect(await controller().signUp('nauja@pastas.lt', 'slaptazodis'), isTrue);
    expect(state().value, contains('Patvirtinkite el. paštą'));
  });

  test('repozitorijos klaida rodoma vartotojui', () async {
    repo.failNext = const AuthFailure('Nėra interneto ryšio. Pabandykite vėliau.');
    expect(await controller().linkEmail('jonas@pastas.lt'), isFalse);
    expect(state().error, isA<AuthFailure>());
    expect(state().error.toString(), 'Nėra interneto ryšio. Pabandykite vėliau.');
  });

  group('slaptažodis', () {
    test('taisyklės: ilgis, raidės ir skaičiai, sutapimas', () async {
      for (final (pass, confirm, message) in [
        ('Abc123', 'Abc123', 'Slaptažodis turi būti bent 8 simbolių.'),
        ('12345678', '12345678', 'Slaptažodyje turi būti ir raidžių, ir skaičių.'),
        ('Kompasas', 'Kompasas', 'Slaptažodyje turi būti ir raidžių, ir skaičių.'),
        ('Kompasas42', 'Kompasas43', 'Slaptažodžiai nesutampa.'),
      ]) {
        expect(await controller().setPassword(pass, confirm), isFalse, reason: pass);
        expect(state().error.toString(), message, reason: pass);
      }
      expect(repo.calls, isEmpty);
    });

    test('lietuviškos raidės tinka', () {
      expect(() => AuthController.validateNewPassword('Žąsis2026', 'Žąsis2026'), returnsNormally);
    });

    test('nustatytas – needsPassword dingsta, pranešimas', () async {
      repo.setUser(const AppUser(id: 'u1', email: 'jonas@pastas.lt', needsPassword: true));
      expect(await controller().setPassword('Kompasas42', 'Kompasas42'), isTrue);

      expect(repo.calls, ['setPassword']);
      expect(repo.currentUser!.needsPassword, isFalse);
      expect(state().value, contains('Slaptažodis nustatytas'));
    });
  });
}
