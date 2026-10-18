import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/progress/domain/models/user_progress.dart';

void main() {
  final t0 = DateTime.utc(2026, 10, 17, 9);

  UserProgress fresh() => UserProgress(
        userId: 'u1',
        lessonId: 'nav-u02-l03',
        lessonVersion: 4,
        status: LessonProgressStatus.inProgress,
        updatedAt: t0,
      );

  test('žvaigždutės pagal tikslumą', () {
    expect(UserProgress.starsForAccuracy(0.5), 0);
    expect(UserProgress.starsForAccuracy(0.6), 1);
    expect(UserProgress.starsForAccuracy(0.8), 2);
    expect(UserProgress.starsForAccuracy(1.0), 3);
  });

  test('bandymas išsaugo geriausią rezultatą ir sumuoja XP', () {
    final first = fresh().withAttempt(accuracy: 1.0, xp: 25, at: t0, lessonVersion: 4);
    final second = first.withAttempt(accuracy: 0.6, xp: 12, at: t0.add(const Duration(days: 1)), lessonVersion: 4);

    expect(first.status, LessonProgressStatus.completed);
    expect(second.stars, 3);
    expect(second.bestAccuracy, 1.0);
    expect(second.xpEarned, 37);
    expect(second.attempts, 2);
    expect(second.completedAt, t0);
    expect(second.isSynced, isFalse);
  });

  test('Supabase eilutės (snake_case) konversija', () {
    final p = fresh().withAttempt(accuracy: 0.8, xp: 18, at: t0, lessonVersion: 4);
    final json = p.toJson();
    expect(json['lesson_id'], 'nav-u02-l03');
    expect(json['status'], 'completed');

    final back = UserProgress.fromJson(json);
    expect(back.stars, 2);
    expect(back.completedAt, t0);
    expect(back.isSynced, isTrue);
  });
}
