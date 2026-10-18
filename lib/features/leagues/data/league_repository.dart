import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/league.dart';

abstract interface class LeagueRepository {
  Future<LeagueStanding> fetchMyLeague();
}

/// RPC `get_my_league` (`supabase/migrations/…_leagues.sql`): tik mano grupė,
/// tik slapyvardžiai; lentelės klientui tiesiogiai neprieinamos.
class SupabaseLeagueRepository implements LeagueRepository {
  SupabaseLeagueRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<LeagueStanding> fetchMyLeague() async {
    final json = await _client.rpc<Json>('get_my_league');
    return LeagueStanding.fromJson(json);
  }
}

/// `null` – lygos nepasiekiamos (Supabase nesukonfigūruotas).
final leagueRepositoryProvider = Provider<LeagueRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseLeagueRepository(client);
});

/// `null` – lygos šioje versijoje nepasiekiamos arba vartotojas neprisijungęs.
final leagueProvider = FutureProvider<LeagueStanding?>((ref) async {
  final repo = ref.watch(leagueRepositoryProvider);
  // Pasikeitus vartotojui – kita lyga.
  final user = await ref.watch(authStateProvider.future);
  if (repo == null || user == null) return null;
  return repo.fetchMyLeague();
});
