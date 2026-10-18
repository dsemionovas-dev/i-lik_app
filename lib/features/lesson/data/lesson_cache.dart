import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

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
/// Rašoma per laikiną failą ir `rename`, kad nutrūkęs įrašas nesugadintų
/// ankstesnės kopijos. Sugadintas ar neperskaitomas failas traktuojamas kaip
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
  Future<Json?> readCatalog() async => _read(await _catalogFile());

  @override
  Future<void> writeCatalog(Json catalog) async => _write(await _catalogFile(), catalog);

  @override
  Future<Json?> readLesson(String lessonId) async => _read(await _lessonFile(lessonId));

  @override
  Future<void> writeLesson(String lessonId, Json content) async =>
      _write(await _lessonFile(lessonId), content);

  Future<Json?> _read(File file) async {
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Json;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> _write(File file, Json data) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(file.path);
  }
}
