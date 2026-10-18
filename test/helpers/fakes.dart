import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:islik/core/utils/json.dart';
import 'package:islik/features/lesson/data/lesson_cache.dart';
import 'package:islik/features/lesson/data/lesson_remote_data_source.dart';
import 'package:islik/features/lesson/domain/models/catalog.dart';

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
