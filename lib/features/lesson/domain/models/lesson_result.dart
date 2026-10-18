import '../../../progress/domain/models/user_progress.dart';
import 'lesson.dart';

/// Pamokos bandymo rezultatas – perduodamas rezultatų ekranui.
class LessonResult {
  LessonResult({
    required this.lessonId,
    required this.correctCount,
    required this.gradedCount,
    required this.xpEarned,
    required this.duration,
    DateTime? completedAt,
  }) : _completedAt = completedAt;

  final String lessonId;
  final int correctCount;
  final int gradedCount;
  final int xpEarned;
  final Duration duration;
  final DateTime? _completedAt;

  /// Kada pamoka baigta (pagal nutylėjimą – sukūrimo metu).
  late final DateTime completedAt = _completedAt ?? DateTime.now();

  /// Pamokos pradžia – po jos gauti ženkleliai rodomi rezultatų ekrane.
  DateTime get startedAt => completedAt.subtract(duration);

  double get accuracy => gradedCount == 0 ? 1 : correctCount / gradedCount;
  int get stars => UserProgress.starsForAccuracy(accuracy);
  bool get isPerfect => correctCount == gradedCount;

  /// XP pagal PRD: bazinis + už kiekvieną teisingą užduotį + be klaidų premija
  /// + combo premija už kiekvieną teisingą iš eilės nuo `comboThreshold`.
  static int calculateXp({
    required Lesson lesson,
    required List<bool> answers,
    required List<LessonItem> gradedItems,
  }) {
    final r = lesson.rewards;
    var xp = r.baseXp;
    var streak = 0;
    for (var i = 0; i < answers.length; i++) {
      if (answers[i]) {
        streak++;
        xp += gradedItems[i].xp;
        if (streak >= r.comboThreshold) xp += r.comboBonusXp;
      } else {
        streak = 0;
      }
    }
    if (answers.every((a) => a)) xp += r.perfectBonusXp;
    return xp;
  }
}
