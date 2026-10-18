import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/json.dart';
import '../domain/models/catalog.dart';

/// Kartu su programėle įdiegtas turinys (`assets/`) – paskutinė atsarga, kai
/// nėra nei interneto, nei kešo (pvz., pirmas paleidimas be ryšio).
class BundledContentSource {
  BundledContentSource([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<ContentCatalog> loadCatalog() async {
    final raw = await _bundle.loadString('assets/catalog.json');
    return ContentCatalog.fromJson(jsonDecode(raw) as Json, source: ContentSource.bundled);
  }

  /// `null`, jei tokios pamokos programėlėje nėra.
  Future<Json?> loadLesson(String lessonId) async {
    try {
      return jsonDecode(await _bundle.loadString('assets/lessons/$lessonId.json')) as Json;
    } on FlutterError {
      // rootBundle meta FlutterError, kai asset'o nėra.
      return null;
    }
  }
}
