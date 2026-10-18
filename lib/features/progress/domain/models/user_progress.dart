import '../../../../core/utils/json.dart';

enum LessonProgressStatus {
  inProgress('in_progress'),
  completed('completed'),

  /// „Auksinė“ – įvaldyta po kartojimo.
  mastered('mastered');

  const LessonProgressStatus(this.key);
  final String key;

  static LessonProgressStatus fromKey(String key) =>
      values.firstWhere((s) => s.key == key, orElse: () => inProgress);
}

/// Vartotojo progresas vienoje pamokoje. Laukai snake_case, nes tai
/// Supabase lentelės `user_lesson_progress` eilutė (pamokų turinys – camelCase).
class UserProgress {
  const UserProgress({
    required this.userId,
    required this.lessonId,
    required this.lessonVersion,
    required this.status,
    required this.updatedAt,
    this.stars = 0,
    this.bestAccuracy = 0,
    this.xpEarned = 0,
    this.attempts = 0,
    this.completedAt,
    this.isSynced = false,
  }) : assert(stars >= 0 && stars <= 3);

  final String userId;
  final String lessonId;

  /// Pamokos versija, kurią vartotojas baigė – pasikeitus turiniui galima pasiūlyti pakartoti.
  final int lessonVersion;
  final LessonProgressStatus status;
  final int stars;

  /// 0.0–1.0
  final double bestAccuracy;
  final int xpEarned;
  final int attempts;
  final DateTime? completedAt;
  final DateTime updatedAt;

  /// Tik vietinė būsena (offline eilė), į serverį nesiunčiama.
  final bool isSynced;

  bool get isCompleted => status != LessonProgressStatus.inProgress;

  /// Žvaigždutės pagal PRD: ≥ 60 % – 1, ≥ 80 % – 2, 100 % – 3.
  static int starsForAccuracy(double accuracy) {
    if (accuracy >= 1.0) return 3;
    if (accuracy >= 0.8) return 2;
    if (accuracy >= 0.6) return 1;
    return 0;
  }

  /// Sujungia naują bandymą su esamu progresu (geriausias rezultatas lieka).
  UserProgress withAttempt({
    required double accuracy,
    required int xp,
    required DateTime at,
    required int lessonVersion,
  }) {
    final best = accuracy > bestAccuracy ? accuracy : bestAccuracy;
    final newStars = starsForAccuracy(best);
    return copyWith(
      lessonVersion: lessonVersion,
      status: newStars > 0 && !isCompleted ? LessonProgressStatus.completed : status,
      stars: newStars,
      bestAccuracy: best,
      xpEarned: xpEarned + xp,
      attempts: attempts + 1,
      completedAt: completedAt ?? (newStars > 0 ? at : null),
      updatedAt: at,
      isSynced: false,
    );
  }

  UserProgress copyWith({
    int? lessonVersion,
    LessonProgressStatus? status,
    int? stars,
    double? bestAccuracy,
    int? xpEarned,
    int? attempts,
    DateTime? completedAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) =>
      UserProgress(
        userId: userId,
        lessonId: lessonId,
        lessonVersion: lessonVersion ?? this.lessonVersion,
        status: status ?? this.status,
        stars: stars ?? this.stars,
        bestAccuracy: bestAccuracy ?? this.bestAccuracy,
        xpEarned: xpEarned ?? this.xpEarned,
        attempts: attempts ?? this.attempts,
        completedAt: completedAt ?? this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
      );

  factory UserProgress.fromJson(Json json) => UserProgress(
        userId: json['user_id'] as String,
        lessonId: json['lesson_id'] as String,
        lessonVersion: json['lesson_version'] as int,
        status: LessonProgressStatus.fromKey(json['status'] as String),
        stars: json['stars'] as int? ?? 0,
        bestAccuracy: (json['best_accuracy'] as num?)?.toDouble() ?? 0,
        xpEarned: json['xp_earned'] as int? ?? 0,
        attempts: json['attempts'] as int? ?? 0,
        completedAt: parseDate(json['completed_at']),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isSynced: true,
      );

  Json toJson() => {
        'user_id': userId,
        'lesson_id': lessonId,
        'lesson_version': lessonVersion,
        'status': status.key,
        'stars': stars,
        'best_accuracy': bestAccuracy,
        'xp_earned': xpEarned,
        'attempts': attempts,
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
