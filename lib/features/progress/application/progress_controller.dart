import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../badges/application/badge_controller.dart';
import '../../leagues/data/league_repository.dart';
import '../../lesson/domain/models/lesson.dart';
import '../../lesson/domain/models/lesson_result.dart';
import '../data/progress_remote_data_source.dart';
import '../data/progress_store.dart';
import '../domain/models/user_progress.dart';
import 'progress_service.dart';

class ProgressState {
  const ProgressState({
    required this.progress,
    required this.pending,
    required this.syncEnabled,
    this.activityDays = const {},
    this.lastSync,
  });

  final Map<String, UserProgress> progress;

  /// Dar neišsiųsti bandymai.
  final int pending;
  final bool syncEnabled;

  /// Dienos su užbaigta pamoka (`YYYY-MM-DD`).
  final Set<String> activityDays;
  final SyncResult? lastSync;

  int get totalXp => progress.values.fold(0, (sum, p) => sum + p.xpEarned);
  int get completedLessons => progress.values.where((p) => p.isCompleted).length;
}

final progressStoreProvider = Provider<ProgressStore>((ref) => FileProgressStore());

final progressRemoteDataSourceProvider = Provider<ProgressRemoteDataSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseProgressRemoteDataSource(client);
});

final progressServiceProvider = Provider<ProgressService>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return ProgressService(
    store: ref.watch(progressStoreProvider),
    remote: ref.watch(progressRemoteDataSourceProvider),
    // Be paskyros sukuriamas svečias; be ryšio – null, bandymai lieka eilėje.
    resolveUserId: () async => (auth.currentUser ?? await auth.ensureSignedIn()).id,
  );
});

class ProgressController extends AsyncNotifier<ProgressState> {
  ProgressService get _service => ref.read(progressServiceProvider);

  @override
  Future<ProgressState> build() async {
    final service = ref.watch(progressServiceProvider);
    // Prisijungus (ar pasikeitus vartotojui) – sinchronizuojam.
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (prev, next) {
      final before = prev?.value?.id, after = next.value?.id;
      if (after != null && after != before) unawaited(syncNow());
    });
    await service.load();
    unawaited(Future.microtask(syncNow));
    return _stateFrom(service);
  }

  /// Užbaigta pamoka: vietinis įrašas iškart, siuntimas fone.
  Future<UserProgress> recordLessonResult(Lesson lesson, LessonResult result) async {
    final progress = await _service.recordAttempt(
      lessonId: lesson.id,
      lessonVersion: lesson.version,
      accuracy: result.accuracy,
      xp: result.xpEarned,
    );
    state = AsyncData(_stateFrom(_service, lastSync: state.value?.lastSync));
    unawaited(syncNow());
    return progress;
  }

  Future<SyncResult> syncNow() async {
    final result = await _service.sync();
    if (!ref.mounted) return result;
    state = AsyncData(_stateFrom(_service, lastSync: result));
    // Išsiųsti bandymai pakeitė savaitės XP lygoje.
    if (result.uploaded > 0) {
      ref
        ..invalidate(leagueProvider)
        // Serveris galėjo suteikti ženklelių (ir už kituose įrenginiuose baigtas pamokas).
        ..invalidate(serverBadgesProvider);
    }
    return result;
  }

  /// Atsijungiant: ištrina šio įrenginio progresą (serveryje jis lieka).
  Future<void> clearLocal() async {
    await _service.clear();
    state = AsyncData(_stateFrom(_service));
  }

  ProgressState _stateFrom(ProgressService service, {SyncResult? lastSync}) {
    final snapshot = service.current;
    return ProgressState(
      progress: Map.unmodifiable(snapshot.progress),
      pending: snapshot.outbox.length,
      syncEnabled: service.syncEnabled,
      activityDays: Set.unmodifiable(snapshot.activityDays),
      lastSync: lastSync,
    );
  }
}

final progressControllerProvider = AsyncNotifierProvider<ProgressController, ProgressState>(ProgressController.new);
