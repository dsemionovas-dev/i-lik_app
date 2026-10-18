import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/json.dart';
import '../domain/badge.dart';

/// Ženklelių sąrašas įdiegtas programėlėje – veikia be interneto.
Future<List<BadgeDefinition>> loadBadgeDefinitions([AssetBundle? bundle]) async {
  final raw = await (bundle ?? rootBundle).loadString('assets/badges.json');
  return BadgeDefinition.listFromJson(jsonDecode(raw) as Json);
}

abstract interface class BadgeRemoteDataSource {
  /// Serverio suteikti ženkleliai (ir kituose įrenginiuose uždirbti): ID → kada.
  Future<Map<String, DateTime>> fetchEarned();
}

/// Lentelė `user_badges` (RLS – tik savo). Suteikia serveris (`award_badges`).
class SupabaseBadgeRemoteDataSource implements BadgeRemoteDataSource {
  SupabaseBadgeRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, DateTime>> fetchEarned() async {
    final rows = await _client.from('user_badges').select('badge_id, earned_at');
    return {for (final r in rows) r['badge_id'] as String: DateTime.parse(r['earned_at'] as String)};
  }
}

/// Kada ženklelis gautas šiame įrenginyje (atskirai kiekvienam vartotojui).
class EarnedBadgeStore {
  EarnedBadgeStore(this._prefs, String userKey) : _key = 'badges_earned_$userKey';

  final SharedPreferences _prefs;
  final String _key;

  Map<String, DateTime> read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Json).map((id, at) => MapEntry(id, DateTime.parse(at as String)));
    } on Object {
      return {};
    }
  }

  Future<void> write(Map<String, DateTime> earned) =>
      _prefs.setString(_key, jsonEncode(earned.map((id, at) => MapEntry(id, at.toUtc().toIso8601String()))));
}
