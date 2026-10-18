import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/data/lesson_cache.dart';

void main() {
  late Directory dir;
  late FileLessonCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('islik_cache_');
    cache = FileLessonCache(rootDirectory: () async => dir);
  });

  tearDown(() => dir.delete(recursive: true));

  test('tuščias kešas grąžina null', () async {
    expect(await cache.readCatalog(), isNull);
    expect(await cache.readLesson('nav-u02-l03'), isNull);
  });

  test('įrašyta – perskaitoma, perrašoma, laikinų failų nelieka', () async {
    await cache.writeCatalog({'courses': <Object>[]});
    await cache.writeLesson('nav-u02-l03', {'id': 'nav-u02-l03', 'version': 4, 'title': 'Ąžuolas'});
    await cache.writeLesson('nav-u02-l03', {'id': 'nav-u02-l03', 'version': 5, 'title': 'Ąžuolas'});

    expect(await cache.readCatalog(), {'courses': <Object>[]});
    expect(await cache.readLesson('nav-u02-l03'), {'id': 'nav-u02-l03', 'version': 5, 'title': 'Ąžuolas'});
    expect(File('${dir.path}/lessons/nav-u02-l03.json').existsSync(), isTrue);
    expect(
      dir.listSync(recursive: true).where((f) => f.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('sugadintas failas traktuojamas kaip kešo nebuvimas', () async {
    await File('${dir.path}/lessons/x.json').create(recursive: true);
    await File('${dir.path}/lessons/x.json').writeAsString('{nebaigtas');
    await File('${dir.path}/catalog.json').writeAsString('[1, 2]');

    expect(await cache.readLesson('x'), isNull);
    expect(await cache.readCatalog(), isNull);
  });

  test('ID su kelio simboliais atmetamas', () async {
    expect(() => cache.writeLesson('../../etc/passwd', {}), throwsArgumentError);
    expect(() => cache.readLesson('a/b'), throwsArgumentError);
  });
}
