import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/core/utils/json.dart';
import 'package:islik/features/lesson/data/bundled_content_source.dart';
import 'package:islik/features/lesson/data/content_repository.dart';
import 'package:islik/features/lesson/domain/models/catalog.dart';

import '../../../helpers/fakes.dart';

/// Tikra pavyzdinė pamoka su pakeista versija.
Json lessonJson({String id = 'nav-u02-l03', int version = 4, String title = 'Kompaso azimutas'}) {
  final json = jsonDecode(File('assets/lessons/nav-u02-l03.json').readAsStringSync()) as Json;
  return {...json, 'id': id, 'version': version, 'title': title};
}

ContentCatalog catalogWith(Map<String, int> versions, {String unitId = 'nav-u02'}) => ContentCatalog(
      courses: const [Course(id: 'navigation', title: 'Navigacija', order: 3)],
      units: [CourseUnit(id: unitId, courseId: 'navigation', title: 'Kompasas', order: 2)],
      lessons: [
        for (final (i, MapEntry(key: id, value: v)) in versions.entries.indexed)
          LessonSummary(
            id: id,
            courseId: 'navigation',
            unitId: id.startsWith('other') ? 'other-unit' : unitId,
            title: id,
            order: i,
            version: v,
          ),
      ],
    );

final bundledCatalog = jsonEncode(catalogWith({'nav-u02-l03': 4}).toJson());

void main() {
  late FakeRemoteDataSource remote;
  late InMemoryLessonCache cache;
  late MapAssetBundle assets;

  ContentRepository repo({bool online = true, Duration timeout = const Duration(seconds: 1)}) =>
      ContentRepository(
        remote: online ? remote : null,
        cache: cache,
        bundled: BundledContentSource(assets),
        timeout: timeout,
      );

  setUp(() {
    remote = FakeRemoteDataSource();
    cache = InMemoryLessonCache();
    assets = MapAssetBundle({
      'assets/catalog.json': bundledCatalog,
      'assets/lessons/nav-u02-l03.json': jsonEncode(lessonJson(title: 'Įdiegta')),
    });
  });

  group('katalogas', () {
    test('iš serverio; įrašomas į kešą', () async {
      remote.catalog = catalogWith({'a': 1, 'b': 2});
      final catalog = await repo().getCatalog();

      expect(catalog.source, ContentSource.remote);
      expect(catalog.lessons.map((l) => l.id), ['a', 'b']);
      expect(ContentCatalog.fromJson(cache.catalog!).lessons.map((l) => l.version), [1, 2]);
    });

    test('serveriui nepasiekiamam – iš kešo', () async {
      cache.catalog = catalogWith({'a': 7}).toJson();
      remote.error = const SocketException('nėra ryšio');

      final catalog = await repo().getCatalog();
      expect(catalog.source, ContentSource.cache);
      expect(catalog.lesson('a')!.version, 7);
    });

    test('nėra nei serverio, nei kešo – įdiegtas', () async {
      remote.error = const SocketException('nėra ryšio');
      final catalog = await repo().getCatalog();
      expect(catalog.source, ContentSource.bundled);
      expect(catalog.lesson('nav-u02-l03'), isNotNull);
    });

    test('be Supabase konfigūracijos serveris nekviečiamas', () async {
      final catalog = await repo(online: false).getCatalog();
      expect(catalog.source, ContentSource.bundled);
      expect(remote.catalogCalls, 0);
    });

    test('per ilgai neatsakantis serveris – laiko riba ir kešas', () async {
      cache.catalog = catalogWith({'a': 1}).toJson();
      final hanging = _HangingRemote();
      final repository = ContentRepository(
        remote: hanging,
        cache: cache,
        bundled: BundledContentSource(assets),
        timeout: const Duration(milliseconds: 20),
      );
      expect((await repository.getCatalog()).source, ContentSource.cache);
    });

    test('kešo įrašymo klaida netrukdo grąžinti duomenų', () async {
      remote.catalog = catalogWith({'a': 1});
      cache.failWrites = true;
      expect((await repo().getCatalog()).source, ContentSource.remote);
    });

    test('niekur nėra – ContentUnavailableException', () async {
      remote.error = const SocketException('nėra ryšio');
      assets.files.clear();
      expect(repo().getCatalog(), throwsA(isA<ContentUnavailableException>()));
    });
  });

  group('pamoka', () {
    test('kešas naujausias – serveris pamokai nekviečiamas', () async {
      remote.catalog = catalogWith({'nav-u02-l03': 4});
      cache.lessons['nav-u02-l03'] = lessonJson(version: 4, title: 'Iš kešo');

      final lesson = await repo().getLesson('nav-u02-l03');
      expect(lesson.title, 'Iš kešo');
      expect(remote.lessonCalls, isEmpty);
    });

    test('kešas pasenęs – atsisiunčiama nauja versija ir įrašoma', () async {
      remote.catalog = catalogWith({'nav-u02-l03': 5});
      remote.lessons['nav-u02-l03'] = lessonJson(version: 5, title: 'Nauja');
      cache.lessons['nav-u02-l03'] = lessonJson(version: 4, title: 'Sena');

      final lesson = await repo().getLesson('nav-u02-l03');
      expect(lesson.title, 'Nauja');
      expect(lesson.version, 5);
      expect(cache.lessons['nav-u02-l03']!['version'], 5);
    });

    test('kešo nėra – atsisiunčiama ir įrašoma', () async {
      remote.catalog = catalogWith({'nav-u02-l03': 4});
      remote.lessons['nav-u02-l03'] = lessonJson(title: 'Iš serverio');

      expect((await repo().getLesson('nav-u02-l03')).title, 'Iš serverio');
      expect(cache.lessons, contains('nav-u02-l03'));
    });

    test('be ryšio – pasenusi kešo kopija', () async {
      cache.catalog = catalogWith({'nav-u02-l03': 5}).toJson();
      cache.lessons['nav-u02-l03'] = lessonJson(version: 4, title: 'Sena');
      remote.error = const SocketException('nėra ryšio');

      final lesson = await repo().getLesson('nav-u02-l03');
      expect(lesson.title, 'Sena');
      expect(remote.lessonCalls, ['nav-u02-l03'], reason: 'bandyta atnaujinti');
    });

    test('be ryšio ir be kešo – įdiegta pamoka', () async {
      remote.error = const SocketException('nėra ryšio');
      expect((await repo().getLesson('nav-u02-l03')).title, 'Įdiegta');
    });

    test('sugadintas serverio JSON į kešą nepatenka', () async {
      remote.catalog = catalogWith({'nav-u02-l03': 5});
      remote.lessons['nav-u02-l03'] = {'id': 'nav-u02-l03', 'title': 'trūksta laukų'};

      expect((await repo().getLesson('nav-u02-l03')).title, 'Įdiegta');
      expect(cache.lessons, isEmpty);
    });

    test('sugadintas kešas ignoruojamas', () async {
      remote.catalog = catalogWith({'nav-u02-l03': 4});
      remote.lessons['nav-u02-l03'] = lessonJson(title: 'Iš serverio');
      cache.lessons['nav-u02-l03'] = {'id': 'nav-u02-l03', 'schemaVersion': '0.1'};

      expect((await repo().getLesson('nav-u02-l03')).title, 'Iš serverio');
    });

    test('niekur nėra – ContentUnavailableException', () async {
      remote.error = const SocketException('nėra ryšio');
      expect(repo().getLesson('nera-tokios'), throwsA(isA<ContentUnavailableException>()));
    });
  });

  group('sinchronizacija', () {
    test('atsisiunčia tik pasenusias pasirinkto skyriaus pamokas', () async {
      remote.catalog = catalogWith({'l1': 2, 'l2': 1, 'l3': 3, 'other-1': 1});
      for (final (id, v) in [('l1', 2), ('l2', 1), ('l3', 3), ('other-1', 1)]) {
        remote.lessons[id] = lessonJson(id: id, version: v);
      }
      cache.lessons['l1'] = lessonJson(id: 'l1', version: 1); // pasenusi
      cache.lessons['l2'] = lessonJson(id: 'l2', version: 1); // naujausia

      final count = await repo().syncLessons(unitId: 'nav-u02');
      expect(count, 2);
      expect(remote.lessonCalls, ['l1', 'l3']);
      expect(cache.lessons['l1']!['version'], 2);
      expect(cache.lessons, isNot(contains('other-1')));
    });

    test('be ryšio nieko nedaro', () async {
      remote.error = const SocketException('nėra ryšio');
      expect(await repo().syncLessons(), 0);
      expect(await repo(online: false).syncLessons(), 0);
    });
  });
}

class _HangingRemote extends FakeRemoteDataSource {
  @override
  Future<ContentCatalog> fetchCatalog() => Completer<ContentCatalog>().future;
}
