import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/core/storage/shared_preferences_provider.dart';
import 'package:islik/core/utils/clock.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';
import 'package:islik/features/badges/application/badge_controller.dart';
import 'package:islik/features/badges/data/badge_repository.dart';
import 'package:islik/features/lesson/data/lesson_repository.dart';
import 'package:islik/features/lesson/domain/models/catalog.dart';
import 'package:islik/features/progress/application/progress_controller.dart';
import 'package:islik/features/progress/data/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import 'badge_test.dart' show done;

class _FakeBadgeRemote implements BadgeRemoteDataSource {
  Map<String, DateTime> earned = {};

  @override
  Future<Map<String, DateTime>> fetchEarned() async => earned;
}

final _catalog = ContentCatalog(
  courses: const [Course(id: 'navigation', title: 'Navigacija', order: 3)],
  units: const [CourseUnit(id: 'nav-u02', courseId: 'navigation', title: 'Kompasas', order: 2)],
  lessons: const [
    LessonSummary(id: 'nav-u02-l03', courseId: 'navigation', unitId: 'nav-u02', title: 'Azimutas', order: 3, version: 4),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryProgressStore store;
  late _FakeBadgeRemote remote;
  late FakeAuthRepository auth;
  late DateTime now;
  late SharedPreferences prefs;

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      progressStoreProvider.overrideWithValue(store),
      catalogProvider.overrideWith((ref) async => _catalog),
      badgeRemoteDataSourceProvider.overrideWithValue(remote),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    c.listen(badgeControllerProvider, (_, _) {});
    await c.read(catalogProvider.future);
    await c.read(badgeControllerProvider.future);
    // Katalogas įkeliamas asinchroniškai – laukiam perskaičiavimo.
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = InMemoryProgressStore();
    remote = _FakeBadgeRemote();
    auth = FakeAuthRepository(user: const AppUser(id: 'u1', isAnonymous: true));
    now = DateTime.utc(2026, 10, 18, 10);
    await store.write(ProgressSnapshot(
      ownerId: 'u1',
      progress: {'nav-u02-l03': done('nav-u02-l03', accuracy: 1, xp: 30)},
      activityDays: {'2026-10-18'},
    ));
  });

  test('vietoje įvertinti ženkleliai gaunami su dabartiniu laiku', () async {
    final c = await container();
    final state = c.read(badgeControllerProvider).value!;

    expect(state.earned.keys, unorderedEquals(['pirmoji-pamoka', 'be-klaidu', 'kompaso-meistras']));
    expect(state.earned['pirmoji-pamoka'], now);
    expect(state.isEarned('serija-7'), isFalse);
    expect(state.stats.currentStreak, 1);
  });

  test('gavimo data įsimenama – vėliau nesikeičia', () async {
    await container();
    now = now.add(const Duration(days: 2));
    final later = (await container()).read(badgeControllerProvider).value!;
    expect(later.earned['pirmoji-pamoka'], DateTime.utc(2026, 10, 18, 10));
  });

  test('serverio ženklelis (uždirbtas kitame įrenginyje) rodomas, ankstesnė data laimi', () async {
    remote.earned = {
      'serija-7': DateTime.utc(2026, 9, 1),
      'pirmoji-pamoka': DateTime.utc(2026, 8, 1),
      // Naujesnės programėlės ženklelis – šioje versijoje nerodomas.
      'ateities-zenklelis': DateTime.utc(2026, 9, 2),
    };
    final state = (await container()).read(badgeControllerProvider).value!;
    expect(state.earned['serija-7'], DateTime.utc(2026, 9, 1));
    expect(state.earned['pirmoji-pamoka'], DateTime.utc(2026, 8, 1));
    expect(state.earned.containsKey('ateities-zenklelis'), isFalse);
  });

  test('earnedSince – per pamoką gauti ženkleliai', () async {
    final state = (await container()).read(badgeControllerProvider).value!;
    expect(state.earnedSince(now.subtract(const Duration(minutes: 5))).map((b) => b.id), contains('pirmoji-pamoka'));
    expect(state.earnedSince(now.add(const Duration(seconds: 1))), isEmpty);
  });

  test('kitas vartotojas – atskiros gavimo datos', () async {
    await container();
    auth.setUser(const AppUser(id: 'u2', email: 'kitas@pastas.lt'));
    now = now.add(const Duration(days: 3));
    final state = (await container()).read(badgeControllerProvider).value!;
    expect(EarnedBadgeStore(prefs, 'u2').read(), isNotEmpty);
    expect(EarnedBadgeStore(prefs, 'u1').read()['pirmoji-pamoka'], DateTime.utc(2026, 10, 18, 10));
    expect(state.earned['pirmoji-pamoka'], isNot(DateTime.utc(2026, 10, 18, 10)));
  });
}
