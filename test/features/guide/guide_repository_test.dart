import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/core/utils/json.dart';
import 'package:islik/features/guide/data/guide_repository.dart';

import '../../helpers/fakes.dart';
import 'guide_test.dart' show bundledGuideJson;

Json version(int v, {String title = 'Skubi pagalba – 112'}) {
  final json = bundledGuideJson();
  final cards = [...json['cards'] as List];
  cards[0] = {...cards[0] as Json, 'title': title};
  return {...json, 'version': v, 'cards': cards};
}

void main() {
  late InMemoryGuideCache cache;
  late FakeGuideRemote remote;
  late MapAssetBundle assets;

  GuideRepository repo({bool online = true}) =>
      GuideRepository(cache: cache, remote: online ? remote : null, bundle: assets, timeout: const Duration(milliseconds: 50));

  setUp(() {
    cache = InMemoryGuideCache();
    remote = FakeGuideRemote();
    assets = MapAssetBundle({GuideRepository.asset: jsonEncode(version(3))});
  });

  group('vietinis (be tinklo)', () {
    test('pirmas paleidimas – įdiegtas gidas, tinklas nekviečiamas', () async {
      final book = await repo().loadLocal();
      expect(book.version, 3);
      expect(remote.calls, 0);
    });

    test('naujesnis kešas laimi', () async {
      cache.saved = version(5, title: 'Iš kešo');
      expect((await repo().loadLocal()).cards.first.title, 'Iš kešo');
    });

    test('programėlę atnaujinus įdiegtas gidas naujesnis už seną kešą', () async {
      cache.saved = version(2, title: 'Senas');
      final book = await repo().loadLocal();
      expect(book.version, 3);
      expect(book.cards.first.title, isNot('Senas'));
    });

    test('sugadintas kešas ignoruojamas', () async {
      cache.saved = {'version': 9, 'cards': 'ne sąrašas'};
      expect((await repo().loadLocal()).version, 3);
    });
  });

  group('atnaujinimas fone', () {
    test('naujesnė serverio versija grąžinama ir įrašoma į kešą', () async {
      remote.guide = version(4, title: 'Nauja');
      final current = await repo().loadLocal();

      final update = await repo().fetchUpdate(current);
      expect(update!.cards.first.title, 'Nauja');
      expect(cache.saved!['version'], 4);
      // Kitą kartą – iš kešo, be tinklo.
      expect((await repo(online: false).loadLocal()).version, 4);
    });

    test('ta pati ar senesnė versija – nieko', () async {
      final current = await repo().loadLocal();
      for (final v in [3, 2]) {
        remote.guide = version(v);
        expect(await repo().fetchUpdate(current), isNull);
      }
      expect(cache.saved, isNull);
    });

    test('netinkamas serverio paketas į kešą nepatenka', () async {
      remote.guide = {...version(7), 'cards': <Object>[]};
      expect(await repo().fetchUpdate(await repo().loadLocal()), isNull);
      expect(cache.saved, isNull);
    });

    test('be ryšio, neatsakant ar be Supabase – tyliai nieko', () async {
      final current = await repo().loadLocal();
      remote.error = const SocketException('nėra ryšio');
      expect(await repo().fetchUpdate(current), isNull);
      expect(await repo(online: false).fetchUpdate(current), isNull);

      final hanging = GuideRepository(cache: cache, remote: _HangingRemote(), bundle: assets, timeout: const Duration(milliseconds: 20));
      expect(await hanging.fetchUpdate(current), isNull);
    });

    test('kešo įrašymo klaida netrukdo naudoti naujos versijos', () async {
      remote.guide = version(4, title: 'Nauja');
      cache.failWrites = true;
      expect((await repo().fetchUpdate(await repo().loadLocal()))!.version, 4);
    });
  });

  test('FileGuideCache: įrašyta perskaitoma', () async {
    final dir = await Directory.systemTemp.createTemp('islik_guide_');
    addTearDown(() => dir.delete(recursive: true));
    final fileCache = FileGuideCache(file: () async => File('${dir.path}/guide.json'));
    expect(await fileCache.read(), isNull);
    await fileCache.write(version(4));
    expect((await fileCache.read())!['version'], 4);
  });
}

class _HangingRemote extends FakeGuideRemote {
  @override
  Future<Json?> fetchGuide(String locale) => Future.delayed(const Duration(days: 1));
}
