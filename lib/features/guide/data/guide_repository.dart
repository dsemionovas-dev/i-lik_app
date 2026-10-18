import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/json_file.dart';
import '../../../core/utils/json.dart';
import '../domain/guide.dart';

abstract interface class GuideCache {
  Future<Json?> read();
  Future<void> write(Json guide);
}

/// `guide.json` programėlės palaikymo kataloge.
class FileGuideCache implements GuideCache {
  FileGuideCache({Future<File> Function()? file}) : _file = file ?? _defaultFile;

  final Future<File> Function() _file;

  static Future<File> _defaultFile() async =>
      File('${(await getApplicationSupportDirectory()).path}/guide.json');

  @override
  Future<Json?> read() async => readJsonFile(await _file());

  @override
  Future<void> write(Json guide) async => writeJsonFile(await _file(), guide);
}

abstract interface class GuideRemoteDataSource {
  /// Naujausias publikuotas gidas arba `null`.
  Future<Json?> fetchGuide(String locale);
}

/// Lentelė `guide_books` (viešai skaitoma, tik publikuota – žr. migraciją).
class SupabaseGuideRemoteDataSource implements GuideRemoteDataSource {
  SupabaseGuideRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Json?> fetchGuide(String locale) async {
    final row = await _client.from('guide_books').select('content').eq('locale', locale).maybeSingle();
    return row?['content'] as Json?;
  }
}

/// Gidas visada atidaromas iš įrenginio (krizės metu nelaukiama tinklo):
/// kešas, jei jis naujesnis už įdiegtą, kitaip – įdiegtas `assets`.
/// Atnaujinimas iš serverio – atskirai, fone ([fetchUpdate]).
class GuideRepository {
  GuideRepository({
    required GuideCache cache,
    GuideRemoteDataSource? remote,
    AssetBundle? bundle,
    this.timeout = const Duration(seconds: 8),
  })  : _cache = cache,
        _remote = remote,
        _bundle = bundle ?? rootBundle;

  static const asset = 'assets/guide/guide.json';

  final GuideCache _cache;
  final GuideRemoteDataSource? _remote;
  final AssetBundle _bundle;
  final Duration timeout;

  Future<GuideBook> loadLocal() async {
    final bundled = GuideBook.fromJson(jsonDecode(await _bundle.loadString(asset)) as Json);
    final cached = await _quietly('skaitant gido kešą', () async {
      final json = await _cache.read();
      return json == null ? null : GuideBook.fromJson(json);
    });
    // Atnaujinus programėlę įdiegtas gidas gali būti naujesnis už seną kešą.
    return cached != null && cached.version > bundled.version ? cached : bundled;
  }

  /// Naujesnė versija iš serverio (ir įrašoma į kešą) arba `null`.
  Future<GuideBook?> fetchUpdate(GuideBook current) async {
    final remote = _remote;
    if (remote == null) return null;
    return _quietly('atnaujinant gidą', () async {
      final json = await remote.fetchGuide(current.locale).timeout(timeout);
      if (json == null) return null;
      final book = GuideBook.fromJson(json); // netinkamas paketas į kešą nepatenka
      if (book.version <= current.version) return null;
      await _quietly('rašant gido kešą', () => _cache.write(json));
      return book;
    });
  }

  Future<T?> _quietly<T>(String what, Future<T?> Function() action) async {
    try {
      return await action();
    } catch (e) {
      developer.log('Klaida $what: $e', name: 'islik.guide');
      return null;
    }
  }
}
