import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/leagues/domain/league.dart';
import 'package:islik/features/leagues/presentation/league_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  List<LeagueZone> zones(LeagueStanding s) => [for (final m in s.members) s.zoneOf(m.rank)];
  List<int> ranksIn(LeagueStanding s, LeagueZone z) => [
    for (final m in s.members)
      if (s.zoneOf(m.rank) == z) m.rank,
  ];

  group('zonos (ta pati taisyklė kaip SQL league_outcome)', () {
    test('pilna grupė: 1–7 kyla, 26–30 krenta', () {
      final s = leagueOf(List.generate(30, (i) => 100 - i), tier: 5);
      expect(ranksIn(s, LeagueZone.promotion), [1, 2, 3, 4, 5, 6, 7]);
      expect(ranksIn(s, LeagueZone.demotion), [26, 27, 28, 29, 30]);
      expect(ranksIn(s, LeagueZone.safe), hasLength(18));
    });

    test('maža grupė: kilimo zona turi pirmenybę, zonos nepersidengia', () {
      final s = leagueOf(List.generate(10, (i) => 100 - i), tier: 5);
      expect(ranksIn(s, LeagueZone.promotion), [1, 2, 3, 4, 5, 6, 7]);
      expect(ranksIn(s, LeagueZone.demotion), [8, 9, 10]);

      expect(zones(leagueOf([5, 4, 3], tier: 5)), everyElement(LeagueZone.promotion));
    });

    test('1 lyga – niekas nekrenta; 10 lyga – niekas nekyla', () {
      expect(ranksIn(leagueOf(List.generate(30, (i) => i), tier: 1), LeagueZone.demotion), isEmpty);
      final top = leagueOf(List.generate(30, (i) => i), tier: 10);
      expect(ranksIn(top, LeagueZone.promotion), isEmpty);
      expect(ranksIn(top, LeagueZone.demotion), [26, 27, 28, 29, 30]);
    });
  });

  test('get_my_league JSON → modelis', () {
    final s = LeagueStanding.fromJson({
      'week_start': '2026-10-12',
      'week_end': '2026-10-18T21:00:00+00:00',
      'tier': 6,
      'tier_name': 'Skautas',
      'max_tier': 10,
      'group_size': 30,
      'promote_count': 7,
      'demote_count': 5,
      'joined': true,
      'members': [
        {'rank': 1, 'display_name': 'Žygeivis 136B1', 'weekly_xp': 30, 'is_me': false},
        {'rank': 2, 'display_name': 'Žygeivis 0F72A', 'weekly_xp': 15, 'is_me': true},
      ],
      'last_week': {'tier': 5, 'tier_name': 'Orientuotojas', 'final_rank': 1, 'outcome': 'promoted'},
    });
    expect(s.tierName, 'Skautas');
    expect(s.weekEnd, DateTime.utc(2026, 10, 18, 21));
    expect(s.me!.displayName, 'Žygeivis 0F72A');
    expect(s.me!.rank, 2);
    expect(s.lastWeek!.outcome, LeagueOutcome.promoted);
    expect(s.lastWeek!.tierName, 'Orientuotojas');
  });

  test('neprisijungęs šią savaitę – tuščia grupė', () {
    final s = LeagueStanding.fromJson({
      'week_start': '2026-10-12',
      'week_end': '2026-10-18T21:00:00+00:00',
      'tier': 1,
      'tier_name': 'Pradinukas',
      'joined': false,
      'members': <Object>[],
      'last_week': null,
    });
    expect(s.joined, isFalse);
    expect(s.me, isNull);
    expect(s.lastWeek, isNull);
  });

  test('likęs laikas', () {
    expect(formatTimeLeft(const Duration(days: 3, hours: 4, minutes: 10)), 'Liko 3 d. 4 val.');
    expect(formatTimeLeft(const Duration(hours: 5, minutes: 7)), 'Liko 5 val. 7 min.');
    expect(formatTimeLeft(const Duration(seconds: 20)), 'Liko 1 min.');
    expect(formatTimeLeft(const Duration(minutes: -1)), 'Savaitė baigiasi');
  });
}
