import '../../../../core/utils/json.dart';

/// Iš kur gautas turinys – UI gali parodyti, kad dirbama offline.
enum ContentSource { remote, cache, bundled }

class Course {
  const Course({required this.id, required this.title, required this.order, this.description});

  final String id;
  final String title;
  final String? description;
  final int order;

  factory Course.fromJson(Json json) => Course(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    order: json['order'] as int? ?? 0,
  );

  Json toJson() => {'id': id, 'title': title, 'description': description, 'order': order};
}

/// Kurso skyrius (PRD: „Unit“).
class CourseUnit {
  const CourseUnit({
    required this.id,
    required this.courseId,
    required this.title,
    required this.order,
    this.description,
  });

  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int order;

  factory CourseUnit.fromJson(Json json) => CourseUnit(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    order: json['order'] as int? ?? 0,
  );

  Json toJson() => {'id': id, 'courseId': courseId, 'title': title, 'description': description, 'order': order};
}

/// Pamokos įrašas kataloge – be turinio. [version] lemia, ar kešuotą paketą reikia atnaujinti.
class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.courseId,
    required this.unitId,
    required this.title,
    required this.order,
    required this.version,
    this.estimatedMinutes = 5,
  });

  final String id;
  final String courseId;
  final String unitId;
  final String title;
  final int order;
  final int version;
  final int estimatedMinutes;

  factory LessonSummary.fromJson(Json json) => LessonSummary(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    unitId: json['unitId'] as String,
    title: json['title'] as String,
    order: json['order'] as int? ?? 0,
    version: json['version'] as int,
    estimatedMinutes: json['estimatedMinutes'] as int? ?? 5,
  );

  Json toJson() => {
    'id': id,
    'courseId': courseId,
    'unitId': unitId,
    'title': title,
    'order': order,
    'version': version,
    'estimatedMinutes': estimatedMinutes,
  };
}

/// Visas turinio katalogas: kursai → skyriai → pamokų santraukos.
/// Mažas (kelios dešimtys KB), todėl gaunamas ir kešuojamas vienu kartu.
class ContentCatalog {
  ContentCatalog({
    required List<Course> courses,
    required List<CourseUnit> units,
    required List<LessonSummary> lessons,
    this.source = ContentSource.remote,
  }) : courses = _sorted(courses, (c) => c.order),
       units = _sorted(units, (u) => u.order),
       lessons = _sorted(lessons, (l) => l.order);

  final List<Course> courses;
  final List<CourseUnit> units;
  final List<LessonSummary> lessons;
  final ContentSource source;

  static List<T> _sorted<T>(List<T> items, int Function(T) order) =>
      List.unmodifiable([...items]..sort((a, b) => order(a).compareTo(order(b))));

  List<CourseUnit> unitsOf(String courseId) => units.where((u) => u.courseId == courseId).toList(growable: false);

  List<LessonSummary> lessonsOf(String unitId) => lessons.where((l) => l.unitId == unitId).toList(growable: false);

  LessonSummary? lesson(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  ContentCatalog withSource(ContentSource source) =>
      ContentCatalog(courses: courses, units: units, lessons: lessons, source: source);

  factory ContentCatalog.fromJson(Json json, {ContentSource source = ContentSource.remote}) => ContentCatalog(
    courses: parseList(json['courses'], Course.fromJson),
    units: parseList(json['units'], CourseUnit.fromJson),
    lessons: parseList(json['lessons'], LessonSummary.fromJson),
    source: source,
  );

  Json toJson() => {
    'courses': courses.map((c) => c.toJson()).toList(),
    'units': units.map((u) => u.toJson()).toList(),
    'lessons': lessons.map((l) => l.toJson()).toList(),
  };
}
