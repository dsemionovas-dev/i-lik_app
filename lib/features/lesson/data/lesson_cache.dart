import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/storage/json_file.dart';
import '../../../core/utils/json.dart';

/// Vietinė atsisiųsto turinio kopija darbui be interneto.
abstract interface class LessonCache {
  Future<Json?> readCatalog();
  Future<void> writeCatalog(Json catalog);
  Future<Json?> readLesson(String lessonId);
  Future<void> writeLesson(String lessonId, Json content);
}

/// JSON failai programėlės palaikymo kataloge:
/// `content_cache/catalog.json` ir `content_cache/lessons/<id>.json`.
///
/// Rašoma atomiškai ([writeJsonFile]); sugadintas failas traktuojamas kaip
/// kešo nebuvimas.
class FileLessonCache implements LessonCache {
  FileLessonCache({Future<Directory> Function()? rootDirectory})
      : _root = rootDirectory ?? _defaultRoot;

  final Future<Directory> Function() _root;
  Directory? _dir;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/content_cache');

  Future<Directory> get _cacheDir async => _dir ??= await _root();

  Future<File> _catalogFile() async => File('${(await _cacheDir).path}/catalog.json');

  Future<File> _lessonFile(String id) async {
    // Id ateina iš serverio – neleidžiame jam išeiti iš kešo katalogo.
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'lessonId', 'Netinkamas pamokos ID');
    }
    return File('${(await _cacheDir).path}/lessons/$id.json');
  }

  @override
  Future<Json?> readCatalog() async => readJsonFile(await _catalogFile());

  @override
  Future<void> writeCatalog(Json catalog) async => writeJsonFile(await _catalogFile(), catalog);

  @override
  Future<Json?> readLesson(String lessonId) async => readJsonFile(await _lessonFile(lessonId));

  @override
  Future<void> writeLesson(String lessonId, Json content) async =>
      writeJsonFile(await _lessonFile(lessonId), content);
}
