import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/models/catalog.dart';
import '../domain/models/lesson.dart';
import 'bundled_content_source.dart';
import 'content_repository.dart';
import 'lesson_cache.dart';
import 'lesson_remote_data_source.dart';

abstract interface class LessonRepository {
  Future<Lesson> getLesson(String lessonId);
}

/// `null`, kai Supabase nesukonfigūruotas – tada naudojamas tik kešas ir `assets`.
final lessonRemoteDataSourceProvider = Provider<LessonRemoteDataSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseLessonRemoteDataSource(client);
});

final lessonCacheProvider = Provider<LessonCache>((ref) => FileLessonCache());

final bundledContentSourceProvider = Provider<BundledContentSource>((ref) => BundledContentSource());

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(
    remote: ref.watch(lessonRemoteDataSourceProvider),
    cache: ref.watch(lessonCacheProvider),
    bundled: ref.watch(bundledContentSourceProvider),
  ),
);

final lessonRepositoryProvider = Provider<LessonRepository>((ref) => ref.watch(contentRepositoryProvider));

final catalogProvider = FutureProvider<ContentCatalog>((ref) => ref.watch(contentRepositoryProvider).getCatalog());

final lessonProvider = FutureProvider.family<Lesson, String>(
  (ref, lessonId) => ref.watch(lessonRepositoryProvider).getLesson(lessonId),
);
