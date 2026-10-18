import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islik/features/leagues/data/league_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;

  SupabaseLeagueRepository repo() => SupabaseLeagueRepository(SupabaseClient(
        'https://test.supabase.co',
        'publishable-key',
        httpClient: MockClient((r) async {
          requests.add(r);
          return respond(r);
        }),
      ));

  http.Response json(http.Request r, Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: r,
      );

  setUp(() => requests = []);

  test('lyga gaunama per RPC get_my_league', () async {
    respond = (r) => json(r, {
          'week_start': '2026-10-12', 'week_end': '2026-10-18T21:00:00+00:00', 'tier': 2,
          'tier_name': 'Stovyklautojas', 'joined': true, 'last_week': null,
          'members': [
            {'rank': 1, 'display_name': 'Žygeivis 136B1', 'weekly_xp': 12, 'is_me': true},
          ],
        });

    final standing = await repo().fetchMyLeague();

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/rest/v1/rpc/get_my_league');
    expect(standing.tierName, 'Stovyklautojas');
    expect(standing.me!.weeklyXp, 12);
  });

  test('neprisijungus serveris atmeta – klaida perduodama UI', () async {
    respond = (r) => json(r, {'code': '28000', 'message': 'not authenticated'}, 401);
    expect(repo().fetchMyLeague(), throwsA(isA<PostgrestException>()));
  });
}
