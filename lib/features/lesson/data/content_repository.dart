import 'dart:async';
import 'dart:developer' as developer;

import '../../../core/utils/json.dart';
import '../domain/models/catalog.dart';
import '../domain/models/lesson.dart';
import 'bundled_content_source.dart';
import 'lesson_cache.dart';
import 'lesson_remote_data_source.dart';
import 'lesson_repository.dart';

/// Turinio nėra nei serveryje (ar jis nepasiekiamas), nei keše, nei programėlėje.
class ContentUnavailableException implements Exception {
  const ContentUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'ContentUnavailableException: $message';
}

/// Turinio gavimo strategija (PRD 5 sk.: offline-first, versijuoti paketai).
///
/// * **Katalogas** – tinklas → kešas → įdiegtas (`assets`). Sėkmingas atsakymas
///   iš tinklo įrašomas į kešą.
/// * **Pamoka** – kešas, jei jo versija ≥ katalogo versijos (be tinklo užklausos);
///   kitaip atsisiunčiama ir įrašoma į kešą; nepavykus – pasenusi kešo kopija,
///   tada įdiegta. Taip pamoka atsidaro ir be interneto.
///
/// Be Supabase konfigūracijos ([remote] == `null`) veikia tik kešas ir `assets`.
class ContentRepository implements LessonRepository {
  ContentRepository({
    required LessonRemoteDataSource? remote,
    required LessonCache cache,
    required BundledContentSource bundled,
    this.timeout = const Duration(seconds: 8),
  }) : _remote = remote,
       _cache = cache,
       _bundled = bundled;

  final LessonRemoteDataSource? _remote;
  final LessonCache _cache;
  final BundledContentSource _bundled;
  final Duration timeout;

  /// Paskutinis gautas katalogas – pamokų versijoms palyginti.
  ContentCatalog? _catalog;

  Future<ContentCatalog> getCatalog() async {
    final remote = _remote;
    if (remote != null) {
      try {
        final catalog = await remote.fetchCatalog().timeout(timeout);
        await _quietly('rašant katalogą į kešą', () => _cache.writeCatalog(catalog.toJson()));
        return _catalog = catalog;
      } catch (e) {
        _log('Katalogo gauti iš serverio nepavyko', e);
      }
    }

    final cached = await _quietly('skaitant katalogą iš kešo', () async {
      final json = await _cache.readCatalog();
      return json == null ? null : ContentCatalog.fromJson(json, source: ContentSource.cache);
    });
    if (cached != null) return _catalog = cached;

    try {
      return _catalog = await _bundled.loadCatalog();
    } catch (e) {
      throw ContentUnavailableException('Katalogas nepasiekiamas: $e');
    }
  }

  @override
  Future<Lesson> getLesson(String lessonId) async {
    final expectedVersion = (await _catalogOrNull())?.lesson(lessonId)?.version;
    final cached = await _readCachedLesson(lessonId);

    if (cached != null && (expectedVersion == null || cached.version >= expectedVersion)) {
      return cached;
    }

    final downloaded = await _download(lessonId);
    if (downloaded != null) return downloaded;

    // Pasenusi kopija geriau nei jokios – ypač krizės metu be ryšio.
    if (cached != null) return cached;

    final bundled = await _quietly('skaitant įdiegtą pamoką', () async {
      final json = await _bundled.loadLesson(lessonId);
      return json == null ? null : Lesson.fromJson(json);
    });
    if (bundled != null) return bundled;

    throw ContentUnavailableException('Pamoka „$lessonId“ nepasiekiama');
  }

  /// Atsisiunčia pamokas, kurių kešo versija senesnė nei kataloge
  /// (pvz., „Atsisiųsti skyrių“ arba fone prisijungus). Grąžina atsisiųstų skaičių.
  Future<int> syncLessons({String? unitId}) async {
    if (_remote == null) return 0;
    final catalog = await getCatalog();
    if (catalog.source != ContentSource.remote) return 0;

    var downloaded = 0;
    final lessons = unitId == null ? catalog.lessons : catalog.lessonsOf(unitId);
    for (final summary in lessons) {
      final cached = await _readCachedLesson(summary.id);
      if (cached != null && cached.version >= summary.version) continue;
      if (await _download(summary.id) != null) downloaded++;
    }
    return downloaded;
  }

  Future<ContentCatalog?> _catalogOrNull() async {
    if (_catalog != null) return _catalog;
    try {
      return await getCatalog();
    } on ContentUnavailableException {
      return null;
    }
  }

  Future<Lesson?> _download(String lessonId) async {
    final remote = _remote;
    if (remote == null) return null;
    try {
      final json = await remote.fetchLessonContent(lessonId).timeout(timeout);
      if (json == null) return null;
      final lesson = Lesson.fromJson(json); // netinkamas JSON į kešą nepatenka
      await _quietly('rašant pamoką į kešą', () => _cache.writeLesson(lessonId, json));
      return lesson;
    } catch (e) {
      _log('Pamokos „$lessonId“ atsisiųsti nepavyko', e);
      return null;
    }
  }

  Future<Lesson?> _readCachedLesson(String lessonId) => _quietly('skaitant pamoką iš kešo', () async {
    final Json? json = await _cache.readLesson(lessonId);
    return json == null ? null : Lesson.fromJson(json);
  });

  /// Kešo klaidos (pilnas diskas, sena schema) neturi sustabdyti pamokos.
  Future<T?> _quietly<T>(String what, Future<T?> Function() action) async {
    try {
      return await action();
    } catch (e) {
      _log('Klaida $what', e);
      return null;
    }
  }

  void _log(String message, Object error) => developer.log('$message: $error', name: 'islik.content');
}
