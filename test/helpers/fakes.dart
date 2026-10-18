import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:islik/core/utils/json.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';
import 'package:islik/features/lesson/data/lesson_cache.dart';
import 'package:islik/features/lesson/data/lesson_remote_data_source.dart';
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
  Future<void> signOut() => _call('signOut', () => setUser(null));
}
