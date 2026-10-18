import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/json.dart';
import '../domain/profile.dart';

abstract interface class ProfileRemoteDataSource {
  Future<Profile?> fetch(String userId);
  Future<void> save(String userId, Profile profile);
}

/// Lentelė `profiles` (RLS – tik savo; vardo taisyklės tikrinamos ir DB).
class SupabaseProfileRemoteDataSource implements ProfileRemoteDataSource {
  SupabaseProfileRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> fetch(String userId) async {
    final row = await _client.from('profiles').select('display_name, avatar').eq('user_id', userId).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<void> save(String userId, Profile profile) =>
      _client.from('profiles').upsert({'user_id': userId, ...profile.toJson()});
}

/// Vietinė kopija – profilis matomas ir be ryšio.
class LocalProfileStore {
  LocalProfileStore(this._prefs);

  final SharedPreferences _prefs;

  String _key(String userId) => 'profile_$userId';

  Profile? read(String userId) {
    final raw = _prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      return Profile.fromJson(jsonDecode(raw) as Json);
    } on Object {
      return null;
    }
  }

  Future<void> write(String userId, Profile profile) => _prefs.setString(_key(userId), jsonEncode(profile.toJson()));
}
