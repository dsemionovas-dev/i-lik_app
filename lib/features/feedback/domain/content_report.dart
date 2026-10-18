import '../../../core/utils/json.dart';

enum ReportCategory {
  contentError('content_error', 'Klaida turinyje', 'Neteisingas atsakymas, faktas ar paaiškinimas'),
  unsafeAdvice('unsafe_advice', 'Pavojingas patarimas', 'Patarimas, kurio laikantis galima susižaloti'),
  appBug('app_bug', 'Programėlės klaida', 'Kažkas neveikia, užstringa ar rodoma netvarkingai'),
  suggestion('suggestion', 'Pasiūlymas', 'Idėja, ką pagerinti');

  const ReportCategory(this.key, this.label, this.hint);

  final String key;
  final String label;
  final String hint;

  static ReportCategory fromKey(String key) => values.firstWhere((c) => c.key == key, orElse: () => appBug);
}

/// Vartotojo pranešimas apie klaidą (PRD: „Ataskaita apie turinio klaidą“).
/// [id] – kliento UUID: pakartotinis siuntimas serveryje nedubliuojamas.
class ContentReport {
  const ContentReport({
    required this.id,
    required this.category,
    required this.message,
    required this.createdAt,
    required this.appVersion,
    required this.platform,
    this.lessonId,
    this.itemId,
    this.guideCardId,
  });

  final String id;
  final ReportCategory category;
  final String message;
  final DateTime createdAt;
  final String appVersion;
  final String platform;
  final String? lessonId;
  final String? itemId;
  final String? guideCardId;

  static const minLength = 10;
  static const maxLength = 2000;

  /// Ta pati taisyklė kaip SQL `content_reports_message_check`. `null` – tinka.
  static String? validateMessage(String raw) {
    final text = raw.trim();
    if (text.length < minLength) return 'Aprašykite plačiau – bent $minLength simbolių.';
    if (text.length > maxLength) return 'Per ilgas aprašymas – daugiausia $maxLength simbolių.';
    return null;
  }

  factory ContentReport.fromJson(Json json) => ContentReport(
    id: json['id'] as String,
    category: ReportCategory.fromKey(json['category'] as String),
    message: json['message'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    appVersion: json['app_version'] as String,
    platform: json['platform'] as String,
    lessonId: json['lesson_id'] as String?,
    itemId: json['item_id'] as String?,
    guideCardId: json['guide_card_id'] as String?,
  );

  /// Ir vietinė eilė, ir `content_reports` eilutė (be user_id – jį nustato serveris).
  Json toJson() => {
    'id': id,
    'category': category.key,
    'message': message,
    'created_at': createdAt.toUtc().toIso8601String(),
    'app_version': appVersion,
    'platform': platform,
    'lesson_id': lessonId,
    'item_id': itemId,
    'guide_card_id': guideCardId,
  };
}
