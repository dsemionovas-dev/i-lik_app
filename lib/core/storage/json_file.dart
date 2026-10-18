import 'dart:convert';
import 'dart:io';

import '../utils/json.dart';

/// Perskaito JSON objektą. Neegzistuojantis ar sugadintas failas – `null`.
Future<Json?> readJsonFile(File file) async {
  try {
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Json;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

/// Įrašo per laikiną failą ir `rename`, kad nutrūkęs įrašas (išsikrovusi
/// baterija, uždaryta programėlė) nesugadintų ankstesnės kopijos.
Future<void> writeJsonFile(File file, Json data) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(jsonEncode(data), flush: true);
  await tmp.rename(file.path);
}
