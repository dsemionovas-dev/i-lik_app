import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/core/utils/json.dart';
import 'package:islik/features/badges/domain/badge.dart';
import 'package:islik/features/lesson/domain/models/catalog.dart';
import 'package:islik/features/progress/domain/models/user_progress.dart';

final _t0 = DateTime(2026, 10, 18, 12);

UserProgress done(String lessonId, {double accuracy = 0.8, int xp = 10, DateTime? at}) =>
    UserProgress.empty(userId: 'u', lessonId: lessonId, lessonVersion: 1, at: at ?? _t0)
        .withAttempt(accuracy: accuracy, xp: xp, at: at ?? _t0, lessonVersion: 1);

List<BadgeDefinition> bundledBadges() =>
    BadgeDefinition.listFromJson(jsonDecode(File('assets/badges.json').readAsStringSync()) as Json);

void main() {
  group('taisyklės', () {
    test('pamokų skaičius, be klaidų, XP', () {
      final stats = BadgeStats.from(progress: {
        'a': done('a', accuracy: 1, xp: 60),
        'b': done('b', xp: 50),
        // Bandyta, bet nebaigta (< 60 %) – neskaičiuojama.
        'c': done('c', accuracy: 0.4, xp: 10),
      });
      expect(stats.completedLessons, 2);
      expect(stats.perfectLessons, 1);
      expect(stats.totalXp, 120);

      expect(const LessonsCompletedRule(1).isMet(stats), isTrue);
      expect(const LessonsCompletedRule(5).progress(stats), (current: 2, target: 5));
      expect(const PerfectLessonsRule(1).isMet(stats), isTrue);
      expect(const TotalXpRule(100).isMet(stats), isTrue);
      expect(const TotalXpRule(1000).isMet(stats), isFalse);
    });

    test('skyrius: visos katalogo pamokos baigtos; nežinomas skyrius – niekada', () {
      final catalog = ContentCatalog(
        courses: const [Course(id: 'nav', title: 'N', order: 1)],
        units: const [CourseUnit(id: 'nav-u02', courseId: 'nav', title: 'Kompasas', order: 1)],
        lessons: const [
          LessonSummary(id: 'l1', courseId: 'nav', unitId: 'nav-u02', title: '1', order: 1, version: 1),
          LessonSummary(id: 'l2', courseId: 'nav', unitId: 'nav-u02', title: '2', order: 2, version: 1),
        ],
      );
      const rule = UnitCompletedRule('nav-u02');

      final half = BadgeStats.from(progress: {'l1': done('l1')}, catalog: catalog);
      expect(rule.progress(half), (current: 1, target: 2));
      expect(rule.isMet(half), isFalse);

      final all = BadgeStats.from(progress: {'l1': done('l1'), 'l2': done('l2')}, catalog: catalog);
      expect(rule.isMet(all), isTrue);
      expect(const UnitCompletedRule('wild-u02').isMet(all), isFalse, reason: 'skyriaus kataloge nėra');
      expect(rule.isMet(BadgeStats.from(progress: {'l1': done('l1'), 'l2': done('l2')})), isFalse,
          reason: 'be katalogo nežinome skyriaus pamokų');
    });

    test('nežinomas taisyklės tipas – niekada neįvykdomas', () {
      final rule = BadgeRule.fromJson({'type': 'league_promoted'});
      expect(rule, isA<UnknownRule>());
      expect(rule.isMet(const BadgeStats(totalXp: 99999)), isFalse);
    });
  });

  group('serija', () {
    DateTime d(String s) => DateTime.parse('$s 12:00');

    test('ilgiausia ir dabartinė', () {
      final days = {'2026-10-01', '2026-10-02', '2026-10-03', '2026-10-10', '2026-10-17', '2026-10-18'};
      expect(Streak.of(days, today: d('2026-10-18')), (longest: 3, current: 2));
      expect(Streak.of(days, today: d('2026-10-19')), (longest: 3, current: 2), reason: 'vakar – dar tęsiasi');
      expect(Streak.of(days, today: d('2026-10-20')), (longest: 3, current: 0), reason: 'praleista diena');
      expect(Streak.of({}, today: d('2026-10-20')), (longest: 0, current: 0));
    });

    test('vasaros laiko perėjimas (kovo 29 d. – 23 val. para) neskaldo serijos', () {
      expect(Streak.of({'2026-03-28', '2026-03-29', '2026-03-30'}, today: d('2026-03-30')).longest, 3);
      expect(Streak.of({'2026-10-24', '2026-10-25', '2026-10-26'}, today: d('2026-10-26')).longest, 3);
    });

    test('serijos taisyklė; dienos ir iš serverio progreso (kitas įrenginys)', () {
      final stats = BadgeStats.from(
        progress: {'a': done('a', at: DateTime(2026, 10, 16, 20))},
        activityDays: {'2026-10-17', '2026-10-18'},
        today: _t0,
      );
      expect(stats.longestStreak, 3);
      expect(stats.currentStreak, 3);
      expect(const StreakRule(3).isMet(stats), isTrue);
      expect(const StreakRule(7).progress(stats), (current: 3, target: 7));
    });
  });

  group('įdiegtas sąrašas', () {
    test('ID unikalūs, taisyklės žinomos, sąlyga aprašyta', () {
      final badges = bundledBadges();
      expect(badges.map((b) => b.id).toSet(), hasLength(badges.length));
      for (final b in badges) {
        expect(b.rule, isNot(isA<UnknownRule>()), reason: b.id);
        expect(b.description, isNotEmpty, reason: b.id);
      }
      expect(badges.map((b) => b.title), containsAll(['Pirmasis žingsnis', '7 dienų serija', 'Ugnies meistras']));
    });

    test('Supabase migracija turi tuos pačius ženklelius ir taisykles', () {
      final sql = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('_badges_profiles.sql'))
          .readAsStringSync();
      for (final raw in (jsonDecode(File('assets/badges.json').readAsStringSync()) as Json)['badges'] as List) {
        final b = raw as Json;
        expect(sql, contains("('${b['id']}', "), reason: '${b['id']} nėra migracijoje');
        expect(sql, contains("'${jsonEncode(b['rule']).replaceAll(',', ', ').replaceAll(':', ': ')}'::jsonb"),
            reason: '${b['id']} taisyklė skiriasi');
      }
    });
  });
}
