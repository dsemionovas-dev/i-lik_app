import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../domain/models/lesson.dart';

abstract interface class LessonRepository {
  Future<Lesson> getLesson(String lessonId);
}

/// Pamokos iš `assets/lessons/` – pradžiai ir testams, kol nėra CMS.
class AssetLessonRepository implements LessonRepository {
  AssetLessonRepository([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<Lesson> getLesson(String lessonId) async {
    final raw = await _bundle.loadString('assets/lessons/$lessonId.json');
    return Lesson.fromJson(jsonDecode(raw) as Json);
  }
}

/// Pamokos iš Supabase lentelės `lessons` (JSONB stulpelis `content`).
/// Vėliau prieš ją dedamas Drift kešas offline režimui.
class SupabaseLessonRepository implements LessonRepository {
  SupabaseLessonRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Lesson> getLesson(String lessonId) async {
    final row = await _client
        .from('lessons')
        .select('content')
        .eq('id', lessonId)
        .single();
    return Lesson.fromJson(row['content'] as Json);
  }
}

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? AssetLessonRepository() : SupabaseLessonRepository(client);
});

final lessonProvider = FutureProvider.family<Lesson, String>(
  (ref, lessonId) => ref.watch(lessonRepositoryProvider).getLesson(lessonId),
);
