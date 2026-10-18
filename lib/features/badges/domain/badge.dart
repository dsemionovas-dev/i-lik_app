import '../../../core/utils/json.dart';
import '../../lesson/domain/models/catalog.dart';
import '../../progress/application/progress_service.dart' show dayKey;
import '../../progress/domain/models/user_progress.dart';

/// Ženklelio sąlyga. Tos pačios taisyklės – SQL `award_badges` (serveris).
sealed class BadgeRule {
  const BadgeRule();

  factory BadgeRule.fromJson(Json json) => switch (json['type']) {
    'lessons_completed' => LessonsCompletedRule(json['count'] as int),
    'perfect_lessons' => PerfectLessonsRule(json['count'] as int),
    'total_xp' => TotalXpRule(json['xp'] as int),
    'streak_days' => StreakRule(json['days'] as int),
    'unit_completed' => UnitCompletedRule(json['unitId'] as String),
    // Naujesnės versijos taisyklė – ženklelį rodo tik serveris.
    final type => UnknownRule(type.toString()),
  };

  /// (dabar, tikslas) – rodoma prie negautų ženklelių, pvz., „3 / 7“.
  ({int current, int target}) progress(BadgeStats stats);

  bool isMet(BadgeStats stats) {
    final p = progress(stats);
    return p.target > 0 && p.current >= p.target;
  }
}

class LessonsCompletedRule extends BadgeRule {
  const LessonsCompletedRule(this.count);
  final int count;

  @override
  ({int current, int target}) progress(BadgeStats s) => (current: s.completedLessons, target: count);
}

class PerfectLessonsRule extends BadgeRule {
  const PerfectLessonsRule(this.count);
  final int count;

  @override
  ({int current, int target}) progress(BadgeStats s) => (current: s.perfectLessons, target: count);
}

class TotalXpRule extends BadgeRule {
  const TotalXpRule(this.xp);
  final int xp;

  @override
  ({int current, int target}) progress(BadgeStats s) => (current: s.totalXp, target: xp);
}

class StreakRule extends BadgeRule {
  const StreakRule(this.days);
  final int days;

  @override
  ({int current, int target}) progress(BadgeStats s) => (current: s.longestStreak, target: days);
}

/// Visos skyriaus pamokos baigtos (bent 1 žvaigždutė).
class UnitCompletedRule extends BadgeRule {
  const UnitCompletedRule(this.unitId);
  final String unitId;

  @override
  ({int current, int target}) progress(BadgeStats s) {
    final lessons = s.unitLessons[unitId] ?? const [];
    return (current: lessons.where(s.completedLessonIds.contains).length, target: lessons.length);
  }
}

class UnknownRule extends BadgeRule {
  const UnknownRule(this.type);
  final String type;

  @override
  ({int current, int target}) progress(BadgeStats s) => (current: 0, target: 0);
}

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.rule,
  });

  final String id;
  final String title;

  /// Sąlyga žmonių kalba – rodoma prie negauto ženklelio.
  final String description;
  final String icon;
  final BadgeRule rule;

  factory BadgeDefinition.fromJson(Json json) => BadgeDefinition(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String? ?? 'badge',
    rule: BadgeRule.fromJson(json['rule'] as Json),
  );

  static List<BadgeDefinition> listFromJson(Json json) => parseList(json['badges'], BadgeDefinition.fromJson);
}

/// Viskas, ko reikia taisyklėms įvertinti.
class BadgeStats {
  const BadgeStats({
    this.completedLessonIds = const {},
    this.perfectLessons = 0,
    this.totalXp = 0,
    this.longestStreak = 0,
    this.currentStreak = 0,
    this.unitLessons = const {},
  });

  final Set<String> completedLessonIds;
  final int perfectLessons;
  final int totalXp;
  final int longestStreak;
  final int currentStreak;

  /// Skyrius → jo pamokų ID (iš turinio katalogo).
  final Map<String, List<String>> unitLessons;

  int get completedLessons => completedLessonIds.length;

  factory BadgeStats.from({
    required Map<String, UserProgress> progress,
    Set<String> activityDays = const {},
    ContentCatalog? catalog,
    DateTime? today,
  }) {
    final completed = {
      for (final p in progress.values)
        if (p.isCompleted) p.lessonId,
    };
    // Dienos ir iš serverio progreso (pvz., kitame įrenginyje baigtos pamokos).
    final days = {
      ...activityDays,
      for (final p in progress.values) ...[if (p.completedAt != null) dayKey(p.completedAt!)],
    };
    final streaks = Streak.of(days, today: today ?? DateTime.now());
    return BadgeStats(
      completedLessonIds: completed,
      perfectLessons: progress.values.where((p) => p.stars == 3).length,
      totalXp: progress.values.fold(0, (sum, p) => sum + p.xpEarned),
      longestStreak: streaks.longest,
      currentStreak: streaks.current,
      unitLessons: catalog == null
          ? const {}
          : {
              for (final u in catalog.units) u.id: [for (final l in catalog.lessonsOf(u.id)) l.id],
            },
    );
  }
}

/// Serija – dienos iš eilės su bent viena pamoka.
abstract final class Streak {
  /// [current] – serija, kuri vis dar tęsiasi (paskutinė diena šiandien arba vakar).
  static ({int longest, int current}) of(Set<String> dayKeys, {required DateTime today}) {
    if (dayKeys.isEmpty) return (longest: 0, current: 0);
    // Kalendorinės dienos kaip UTC datos – vasaros laiko perėjimas netrukdo skaičiuoti.
    final days = dayKeys.map(DateTime.parse).map((d) => DateTime.utc(d.year, d.month, d.day)).toSet().toList()..sort();
    var longest = 1, run = 1;
    for (var i = 1; i < days.length; i++) {
      run = days[i].difference(days[i - 1]).inDays == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    final t = DateTime.parse(dayKey(today));
    final todayUtc = DateTime.utc(t.year, t.month, t.day);
    final sinceLast = todayUtc.difference(days.last).inDays;
    return (longest: longest, current: sinceLast <= 1 ? run : 0);
  }
}
