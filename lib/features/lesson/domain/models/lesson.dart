import '../../../../core/utils/json.dart';
import 'lesson_item.dart';
import 'media_image.dart';

export 'lesson_item.dart';
export 'media_image.dart';
export 'question_option.dart';

/// Pamokos XP taisyklės.
class LessonRewards {
  const LessonRewards({
    this.baseXp = 10,
    this.perfectBonusXp = 5,
    this.comboBonusXp = 2,
    this.comboThreshold = 5,
    this.badgeId,
  });

  final int baseXp;
  final int perfectBonusXp;
  final int comboBonusXp;
  final int comboThreshold;
  final String? badgeId;

  factory LessonRewards.fromJson(Object? json) {
    if (json == null) return const LessonRewards();
    final map = json as Json;
    return LessonRewards(
      baseXp: map['baseXp'] as int? ?? 10,
      perfectBonusXp: map['perfectBonusXp'] as int? ?? 5,
      comboBonusXp: map['comboBonusXp'] as int? ?? 2,
      comboThreshold: map['comboThreshold'] as int? ?? 5,
      badgeId: map['badgeId'] as String?,
    );
  }

  Json toJson() => {
        'baseXp': baseXp,
        'perfectBonusXp': perfectBonusXp,
        'comboBonusXp': comboBonusXp,
        'comboThreshold': comboThreshold,
        'badgeId': badgeId,
      };
}

class LessonSource {
  const LessonSource({required this.title, required this.url});

  final String title;
  final String url;

  factory LessonSource.fromJson(Json json) => LessonSource(
        title: json['title'] as String,
        url: json['url'] as String,
      );

  Json toJson() => {'title': title, 'url': url};
}

enum ReviewStatus { draft, inReview, approved, rejected }

/// Eksperto patvirtinimas – programėlėje rodomos tik `approved` pamokos.
class LessonReview {
  const LessonReview({required this.status, this.reviewedBy, this.reviewedAt});

  final ReviewStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  static const _statusKeys = {
    ReviewStatus.draft: 'draft',
    ReviewStatus.inReview: 'in_review',
    ReviewStatus.approved: 'approved',
    ReviewStatus.rejected: 'rejected',
  };

  factory LessonReview.fromJson(Json json) => LessonReview(
        status: _statusKeys.entries
            .firstWhere((e) => e.value == json['status'],
                orElse: () => const MapEntry(ReviewStatus.draft, 'draft'))
            .key,
        reviewedBy: json['reviewedBy'] as String?,
        reviewedAt: parseDate(json['reviewedAt']),
      );

  Json toJson() => {
        'status': _statusKeys[status],
        'reviewedBy': reviewedBy,
        // Tik data, kaip CMS eksporte (YYYY-MM-DD).
        'reviewedAt': reviewedAt?.toIso8601String().substring(0, 10),
      };
}

/// Viena pamoka – tiksliai atitinka PRD 6 skyriaus JSON schemą.
class Lesson {
  const Lesson({
    required this.id,
    required this.courseId,
    required this.unitId,
    required this.order,
    required this.version,
    required this.title,
    required this.items,
    this.schemaVersion = '1.0',
    this.locale = 'lt-LT',
    this.subtitle,
    this.difficulty = 1,
    this.estimatedMinutes = 5,
    this.coverImage,
    this.tags = const [],
    this.prerequisites = const [],
    this.rewards = const LessonRewards(),
    this.heartsEnabled = true,
    this.sources = const [],
    this.review,
  });

  final String schemaVersion;
  final String id;
  final String courseId;
  final String unitId;
  final int order;
  final int version;
  final String locale;
  final String title;
  final String? subtitle;
  final int difficulty;
  final int estimatedMinutes;
  final MediaImage? coverImage;
  final List<String> tags;
  final List<String> prerequisites;
  final LessonRewards rewards;
  final bool heartsEnabled;
  final List<LessonItem> items;
  final List<LessonSource> sources;
  final LessonReview? review;

  /// Užduotys, kurias ši programėlės versija moka parodyti.
  List<LessonItem> get playableItems =>
      items.where((i) => i is! UnsupportedItem).toList(growable: false);

  int get gradedItemCount => playableItems.where((i) => i.isGraded).length;

  factory Lesson.fromJson(Json json) => Lesson(
        schemaVersion: json['schemaVersion'] as String? ?? '1.0',
        id: json['id'] as String,
        courseId: json['courseId'] as String,
        unitId: json['unitId'] as String,
        order: json['order'] as int,
        version: json['version'] as int,
        locale: json['locale'] as String? ?? 'lt-LT',
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        difficulty: json['difficulty'] as int? ?? 1,
        estimatedMinutes: json['estimatedMinutes'] as int? ?? 5,
        coverImage: MediaImage.maybeFromJson(json['coverImage']),
        tags: parseStringList(json['tags']),
        prerequisites: parseStringList(json['prerequisites']),
        rewards: LessonRewards.fromJson(json['rewards']),
        heartsEnabled: json['heartsEnabled'] as bool? ?? true,
        items: parseList(json['items'], LessonItem.fromJson),
        sources: parseList(json['sources'], LessonSource.fromJson),
        review: json['review'] == null
            ? null
            : LessonReview.fromJson(json['review'] as Json),
      );

  Json toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'courseId': courseId,
        'unitId': unitId,
        'order': order,
        'version': version,
        'locale': locale,
        'title': title,
        'subtitle': subtitle,
        'difficulty': difficulty,
        'estimatedMinutes': estimatedMinutes,
        'coverImage': coverImage?.toJson(),
        'tags': tags,
        'prerequisites': prerequisites,
        'rewards': rewards.toJson(),
        'heartsEnabled': heartsEnabled,
        'items': items.map((i) => i.toJson()).toList(),
        'sources': sources.map((s) => s.toJson()).toList(),
        'review': review?.toJson(),
      };
}
