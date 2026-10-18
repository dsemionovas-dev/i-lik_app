import '../../../core/utils/json.dart';

enum LeagueZone { promotion, safe, demotion }

enum LeagueOutcome {
  promoted,
  stayed,
  demoted;

  static LeagueOutcome? fromKey(String? key) => switch (key) {
    'promoted' => promoted,
    'stayed' => stayed,
    'demoted' => demoted,
    _ => null,
  };
}

class LeagueMember {
  const LeagueMember({required this.rank, required this.displayName, required this.weeklyXp, this.isMe = false});

  final int rank;
  final String displayName;
  final int weeklyXp;
  final bool isMe;

  factory LeagueMember.fromJson(Json json) => LeagueMember(
    rank: json['rank'] as int,
    displayName: json['display_name'] as String,
    weeklyXp: json['weekly_xp'] as int,
    isMe: json['is_me'] as bool? ?? false,
  );
}

/// Praėjusios savaitės rezultatas – rodomas kaip „Pakilai į …“.
class LeagueLastWeek {
  const LeagueLastWeek({required this.tier, required this.tierName, required this.finalRank, required this.outcome});

  final int tier;
  final String tierName;
  final int finalRank;
  final LeagueOutcome outcome;

  factory LeagueLastWeek.fromJson(Json json) => LeagueLastWeek(
    tier: json['tier'] as int,
    tierName: json['tier_name'] as String,
    finalRank: json['final_rank'] as int,
    outcome: LeagueOutcome.fromKey(json['outcome'] as String?) ?? LeagueOutcome.stayed,
  );
}

/// Mano šios savaitės lyga (RPC `get_my_league`). Taisyklių skaičiai ateina iš
/// serverio, kad klientas ir savaitės uždarymas niekada neišsiskirtų.
class LeagueStanding {
  const LeagueStanding({
    required this.tier,
    required this.tierName,
    required this.weekStart,
    required this.weekEnd,
    required this.members,
    this.joined = true,
    this.maxTier = 10,
    this.groupSize = 30,
    this.promoteCount = 7,
    this.demoteCount = 5,
    this.lastWeek,
  });

  final int tier;
  final String tierName;
  final DateTime weekStart;

  /// Kada savaitė baigiasi (pirmadienis 00:00 Vilniaus laiku).
  final DateTime weekEnd;
  final List<LeagueMember> members;

  /// `false` – šią savaitę dar neuždirbta XP, grupės nėra.
  final bool joined;
  final int maxTier;
  final int groupSize;
  final int promoteCount;
  final int demoteCount;
  final LeagueLastWeek? lastWeek;

  LeagueMember? get me {
    for (final m in members) {
      if (m.isMe) return m;
    }
    return null;
  }

  /// Ta pati taisyklė kaip SQL `league_outcome`: top N kyla, apatiniai M krenta,
  /// mažoje grupėje kilimo zona turi pirmenybę; kraštinėse lygose zonų nėra.
  LeagueZone zoneOf(int rank) {
    final size = members.length;
    if (rank <= promoteCount && tier < maxTier) return LeagueZone.promotion;
    final lastSafe = size - demoteCount > promoteCount ? size - demoteCount : promoteCount;
    if (rank > lastSafe && tier > 1) return LeagueZone.demotion;
    return LeagueZone.safe;
  }

  factory LeagueStanding.fromJson(Json json) => LeagueStanding(
    tier: json['tier'] as int,
    tierName: json['tier_name'] as String,
    weekStart: DateTime.parse(json['week_start'] as String),
    weekEnd: DateTime.parse(json['week_end'] as String),
    joined: json['joined'] as bool? ?? false,
    maxTier: json['max_tier'] as int? ?? 10,
    groupSize: json['group_size'] as int? ?? 30,
    promoteCount: json['promote_count'] as int? ?? 7,
    demoteCount: json['demote_count'] as int? ?? 5,
    members: parseList(json['members'], LeagueMember.fromJson),
    lastWeek: json['last_week'] == null ? null : LeagueLastWeek.fromJson(json['last_week'] as Json),
  );
}
