import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:islik/core/utils/json.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';
import 'package:islik/features/lesson/data/lesson_cache.dart';
import 'package:islik/features/lesson/data/lesson_remote_data_source.dart';
import 'package:islik/features/guide/data/guide_repository.dart';
import 'package:islik/features/leagues/data/league_repository.dart';
import 'package:islik/features/leagues/domain/league.dart';
import 'package:islik/features/lesson/domain/models/catalog.dart';
import 'package:islik/features/progress/data/progress_remote_data_source.dart';
import 'package:islik/features/progress/data/progress_store.dart';
import 'package:islik/features/progress/domain/models/lesson_attempt.dart';
import 'package:islik/features/progress/domain/models/user_progress.dart';

/// Kešas atmintyje: widget testuose tikras failų I/O fake-async zonoje nesibaigia.
class InMemoryLessonCache implements LessonCache {
  Json? catalog;
  final lessons = <String, Json>{};
  var failWrites = false;

  @override
  Future<Json?> readCatalog() async => catalog;

  @override
  Future<void> writeCatalog(Json catalog) async {
    if (failWrites) throw StateError('diskas pilnas');
    this.catalog = catalog;
  }

  @override
  Future<Json?> readLesson(String lessonId) async => lessons[lessonId];

  @override
  Future<void> writeLesson(String lessonId, Json content) async {
    if (failWrites) throw StateError('diskas pilnas');
    lessons[lessonId] = content;
  }
}

/// Valdomas „serveris“: galima įjungti gedimą ir skaičiuoti užklausas.
class FakeRemoteDataSource implements LessonRemoteDataSource {
  FakeRemoteDataSource({ContentCatalog? catalog, Map<String, Json>? lessons})
      : catalog = catalog ?? ContentCatalog(courses: const [], units: const [], lessons: const []),
        lessons = lessons ?? {};

  ContentCatalog catalog;
  final Map<String, Json> lessons;
  Object? error;
  var catalogCalls = 0;
  final lessonCalls = <String>[];

  @override
  Future<ContentCatalog> fetchCatalog() async {
    catalogCalls++;
    if (error != null) throw error!;
    return catalog;
  }

  @override
  Future<Json?> fetchLessonContent(String lessonId) async {
    lessonCalls.add(lessonId);
    if (error != null) throw error!;
    // Kopija, kaip iš tinklo.
    final json = lessons[lessonId];
    return json == null ? null : jsonDecode(jsonEncode(json)) as Json;
  }
}

/// Asset'ai iš žemėlapio: galima imituoti, kad pamokos programėlėje nėra.
class MapAssetBundle extends CachingAssetBundle {
  MapAssetBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final text = files[key];
    if (text == null) throw FlutterError('Unable to load asset: "$key".');
    final bytes = utf8.encode(text);
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

/// Progreso saugykla atmintyje; JSON per kopiją – kaip tikras įrašas į diską.
class InMemoryProgressStore implements ProgressStore {
  Json? saved;
  var writes = 0;

  @override
  Future<ProgressSnapshot?> read() async => saved == null ? null : ProgressSnapshot.fromJson(saved!);

  @override
  Future<void> write(ProgressSnapshot snapshot) async {
    writes++;
    saved = jsonDecode(jsonEncode(snapshot.toJson())) as Json;
  }
}

/// „Serveris“, sujungiantis bandymus kaip SQL `record_lesson_attempt`
/// (idempotentiška pagal ID; XP sumuojamas, žvaigždutės – geriausios).
class FakeProgressRemote implements ProgressRemoteDataSource {
  FakeProgressRemote({this.userId = 'user-1'});

  String userId;
  final received = <LessonAttempt>[];
  final rows = <String, UserProgress>{};

  /// Klaida kiekvienam bandymui (pvz., nėra ryšio); `null` – veikia.
  Object? Function(LessonAttempt attempt)? failWith;
  Object? fetchError;

  /// Jei nustatyta – `recordAttempt` laukia, kol bus užbaigta.
  Completer<void>? gate;

  @override
  Future<void> recordAttempt(LessonAttempt a) async {
    if (gate != null) await gate!.future;
    final error = failWith?.call(a);
    if (error != null) throw error;
    if (received.any((r) => r.id == a.id)) return;
    received.add(a);
    final current = rows[a.lessonId] ??
        UserProgress.empty(userId: userId, lessonId: a.lessonId, lessonVersion: a.lessonVersion, at: a.completedAt);
    rows[a.lessonId] =
        current.withAttempt(accuracy: a.accuracy, xp: a.xp, at: a.completedAt, lessonVersion: a.lessonVersion)
            .copyWith(isSynced: true);
  }

  @override
  Future<List<UserProgress>> fetchProgress() async {
    if (fetchError != null) throw fetchError!;
    return rows.values.toList();
  }
}

/// Valdoma autentifikacija testams.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? user, this.supportsAccounts = true}) : _user = user;

  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();
  final calls = <String>[];
  AuthFailure? failNext;

  @override
  final bool supportsAccounts;

  @override
  AppUser? get currentUser => _user;

  void setUser(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  Future<T> _call<T>(String name, T Function() result) async {
    calls.add(name);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
    return result();
  }

  @override
  Future<AppUser> ensureSignedIn() => _call('ensureSignedIn', () {
        if (_user == null) setUser(const AppUser(id: 'guest-1', isAnonymous: true));
        return _user!;
      });

  @override
  Future<AppUser> signInWithEmail(String email, String password) => _call('signIn:$email', () {
        setUser(AppUser(id: 'user-$email', email: email));
        return _user!;
      });

  @override
  Future<bool> signUpWithEmail(String email, String password) => _call('signUp:$email', () => true);

  @override
  Future<void> linkEmail(String email) => _call('link:$email', () {});

  @override
  Future<void> setPassword(String password) => _call('setPassword', () {
        final u = _user!;
        setUser(AppUser(id: u.id, email: u.email, isAnonymous: u.isAnonymous));
      });

  /// Imituoja, kad vartotojas tuo metu patvirtino el. paštą naršyklėje.
  AppUser? afterRefresh;

  @override
  Future<void> refreshUser() => _call('refreshUser', () {
        if (afterRefresh != null) setUser(afterRefresh);
      });

  /// Teisingas atstatymo kodas.
  String resetCode = '123456';
  final _recoveries = StreamController<void>.broadcast();

  void emitPasswordRecovery() => _recoveries.add(null);

  @override
  Future<void> sendPasswordReset(String email) => _call('reset:$email', () {});

  @override
  Future<AppUser> verifyPasswordResetCode(String email, String code) => _call('verify:$code', () {
        if (code != resetCode) throw const AuthFailure('Kodas neteisingas arba nebegalioja. Paprašykite naujo.');
        setUser(AppUser(id: 'user-$email', email: email));
        return _user!;
      });

  @override
  Stream<void> passwordRecoveryEvents() => _recoveries.stream;

  @override
  Future<void> signOut() => _call('signOut', () => setUser(null));
}

/// Lyga testams: [standing] arba [error].
class FakeLeagueRepository implements LeagueRepository {
  FakeLeagueRepository([this.standing]);

  LeagueStanding? standing;
  Object? error;
  var calls = 0;

  @override
  Future<LeagueStanding> fetchMyLeague() async {
    calls++;
    if (error != null) throw error!;
    return standing!;
  }
}

/// Grupė iš [xp] (mažėjančia tvarka); [meAt] – mano vieta (1..).
LeagueStanding leagueOf(
  List<int> xp, {
  int tier = 3,
  int? meAt,
  bool joined = true,
  LeagueLastWeek? lastWeek,
  DateTime? weekEnd,
}) =>
    LeagueStanding(
      tier: tier,
      tierName: const ['Pradinukas', 'Stovyklautojas', 'Žygeivis', 'Pėdsekys', 'Orientuotojas',
          'Skautas', 'Tyrinėtojas', 'Gelbėtojas', 'Instruktorius', 'Rangeris'][tier - 1],
      weekStart: DateTime.utc(2026, 10, 12),
      weekEnd: weekEnd ?? DateTime.utc(2026, 10, 18, 21),
      joined: joined,
      lastWeek: lastWeek,
      members: [
        for (final (i, x) in xp.indexed)
          LeagueMember(rank: i + 1, displayName: 'Žygeivis ${i + 1}', weeklyXp: x, isMe: meAt == i + 1),
      ],
    );

class InMemoryGuideCache implements GuideCache {
  Json? saved;
  var failWrites = false;

  @override
  Future<Json?> read() async => saved;

  @override
  Future<void> write(Json guide) async {
    if (failWrites) throw StateError('diskas pilnas');
    saved = guide;
  }
}

class FakeGuideRemote implements GuideRemoteDataSource {
  FakeGuideRemote([this.guide]);

  Json? guide;
  Object? error;
  var calls = 0;

  @override
  Future<Json?> fetchGuide(String locale) async {
    calls++;
    if (error != null) throw error!;
    return guide;
  }
}
