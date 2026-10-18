import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/clock.dart';
import '../../auth/data/auth_repository.dart';
import '../../lesson/data/lesson_repository.dart';
import '../../progress/application/progress_controller.dart';
import '../data/badge_repository.dart';
import '../domain/badge.dart';

class BadgeState {
  const BadgeState({required this.definitions, required this.earned, required this.stats});

  final List<BadgeDefinition> definitions;

  /// Gauti ženkleliai → kada gauti.
  final Map<String, DateTime> earned;
  final BadgeStats stats;

  bool isEarned(String id) => earned.containsKey(id);

  /// Gauti ne anksčiau nei [time] (pvz., per ką tik baigtą pamoką).
  List<BadgeDefinition> earnedSince(DateTime time) =>
      [for (final d in definitions) if (earned[d.id] case final at? when !at.isBefore(time)) d];
}

final badgeDefinitionsProvider = FutureProvider<List<BadgeDefinition>>((ref) => loadBadgeDefinitions());

final badgeRemoteDataSourceProvider = Provider<BadgeRemoteDataSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseBadgeRemoteDataSource(client);
});

/// Serverio ženkleliai; be ryšio ar be serverio – tuščia (vietinis įvertinimas vis tiek veikia).
final serverBadgesProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  final remote = ref.watch(badgeRemoteDataSourceProvider);
  final user = await ref.watch(authStateProvider.future);
  if (remote == null || user == null) return const {};
  try {
    return await remote.fetchEarned();
  } on Object {
    return const {};
  }
});

/// Ženkleliai: sąlygos įvertinamos įrenginyje (iškart, ir be ryšio) ir sujungiamos
/// su serverio suteiktais. Gavimo data įsimenama pirmą kartą pastebėjus.
class BadgeController extends AsyncNotifier<BadgeState> {
  @override
  Future<BadgeState> build() async {
    final definitions = await ref.watch(badgeDefinitionsProvider.future);
    final progress = await ref.watch(progressControllerProvider.future);
    // Katalogas (skyrių pamokos) – kai jau įkeltas; įkėlus perskaičiuojama.
    final catalog = ref.watch(catalogProvider).value;
    final server = ref.watch(serverBadgesProvider).value ?? const {};
    final user = ref.watch(authStateProvider).value;
    final now = ref.read(clockProvider)();

    final stats = BadgeStats.from(
      progress: progress.progress,
      activityDays: progress.activityDays,
      catalog: catalog,
      today: now,
    );

    final store = EarnedBadgeStore(ref.watch(sharedPreferencesProvider), user?.id ?? 'local');
    final stored = store.read();
    final earned = <String, DateTime>{};
    for (final d in definitions) {
      final remoteAt = server[d.id];
      if (!d.rule.isMet(stats) && remoteAt == null) continue;
      final candidates = [?stored[d.id], ?remoteAt];
      earned[d.id] = candidates.isEmpty ? now : candidates.reduce((a, b) => a.isBefore(b) ? a : b);
    }
    // Serverio ženkleliai, kurių šios versijos sąraše nėra, nerodomi.
    if (!_sameKeys(earned, stored)) await store.write({...stored, ...earned});

    return BadgeState(definitions: definitions, earned: earned, stats: stats);
  }

  static bool _sameKeys(Map<String, DateTime> a, Map<String, DateTime> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

final badgeControllerProvider = AsyncNotifierProvider<BadgeController, BadgeState>(BadgeController.new);
