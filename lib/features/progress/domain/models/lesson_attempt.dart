import '../../../../core/utils/json.dart';

/// Vienas pamokos užbaigimas – siuntimo eilės (outbox) įrašas.
/// [id] (UUID) leidžia serveriui atmesti pakartotinai išsiųstą bandymą.
class LessonAttempt {
  const LessonAttempt({
    required this.id,
    required this.lessonId,
    required this.lessonVersion,
    required this.accuracy,
    required this.xp,
    required this.completedAt,
  });

  final String id;
  final String lessonId;
  final int lessonVersion;

  /// 0.0–1.0
  final double accuracy;
  final int xp;
  final DateTime completedAt;

  factory LessonAttempt.fromJson(Json json) => LessonAttempt(
        id: json['id'] as String,
        lessonId: json['lessonId'] as String,
        lessonVersion: json['lessonVersion'] as int,
        accuracy: (json['accuracy'] as num).toDouble(),
        xp: json['xp'] as int,
        completedAt: DateTime.parse(json['completedAt'] as String),
      );

  Json toJson() => {
        'id': id,
        'lessonId': lessonId,
        'lessonVersion': lessonVersion,
        'accuracy': accuracy,
        'xp': xp,
        'completedAt': completedAt.toUtc().toIso8601String(),
      };

  /// `record_lesson_attempt` RPC parametrai.
  Json toRpcParams() => {
        'p_attempt_id': id,
        'p_lesson_id': lessonId,
        'p_lesson_version': lessonVersion,
        'p_accuracy': accuracy,
        'p_xp': xp,
        'p_completed_at': completedAt.toUtc().toIso8601String(),
      };
}
