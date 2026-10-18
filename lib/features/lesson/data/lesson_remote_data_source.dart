import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/json.dart';
import '../domain/models/catalog.dart';

/// Turinys iš serverio. Grąžina „žalią“ pamokos JSON, kad repozitorija galėtų
/// jį kešuoti tokį, koks atėjo.
abstract interface class LessonRemoteDataSource {
  Future<ContentCatalog> fetchCatalog();

  /// `null`, jei tokios (publikuotos) pamokos nėra.
  Future<Json?> fetchLessonContent(String lessonId);
}

/// Supabase lentelės `courses`, `units`, `lessons` (žr. `supabase/migrations/`).
/// Matomumą (tik publikuotas turinys) užtikrina RLS politikos, ne kliento filtrai.
class SupabaseLessonRemoteDataSource implements LessonRemoteDataSource {
  SupabaseLessonRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<ContentCatalog> fetchCatalog() async {
    final List<Map<String, dynamic>> courses, units, lessons;
    try {
      (courses, units, lessons) = await (
        _client.from('courses').select('id, title, description, sort_order').order('sort_order', ascending: true),
        _client.from('units').select('id, course_id, title, description, sort_order').order('sort_order', ascending: true),
        _client
            .from('lessons')
            .select('id, course_id, unit_id, title, sort_order, version, estimated_minutes')
            .order('sort_order', ascending: true),
      ).wait;
    } on ParallelWaitError<Object?, (AsyncError?, AsyncError?, AsyncError?)> catch (e) {
      // Perduodame pirmą tikrą klaidą (pvz., PostgrestException), ne apvalkalą.
      final first = [e.errors.$1, e.errors.$2, e.errors.$3].nonNulls.first;
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }

    return ContentCatalog(
      courses: [
        for (final r in courses)
          Course(
            id: r['id'] as String,
            title: r['title'] as String,
            description: r['description'] as String?,
            order: r['sort_order'] as int,
          ),
      ],
      units: [
        for (final r in units)
          CourseUnit(
            id: r['id'] as String,
            courseId: r['course_id'] as String,
            title: r['title'] as String,
            description: r['description'] as String?,
            order: r['sort_order'] as int,
          ),
      ],
      lessons: [
        for (final r in lessons)
          LessonSummary(
            id: r['id'] as String,
            courseId: r['course_id'] as String,
            unitId: r['unit_id'] as String,
            title: r['title'] as String,
            order: r['sort_order'] as int,
            version: r['version'] as int,
            estimatedMinutes: r['estimated_minutes'] as int? ?? 5,
          ),
      ],
    );
  }

  @override
  Future<Json?> fetchLessonContent(String lessonId) async {
    final row = await _client.from('lessons').select('content').eq('id', lessonId).maybeSingle();
    return row?['content'] as Json?;
  }
}
