import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/guide_repository.dart';
import '../domain/guide.dart';

final guideCacheProvider = Provider<GuideCache>((ref) => FileGuideCache());

final guideRepositoryProvider = Provider<GuideRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return GuideRepository(
    cache: ref.watch(guideCacheProvider),
    remote: client == null ? null : SupabaseGuideRemoteDataSource(client),
  );
});

/// Gidas iš įrenginio iškart; naujesnė versija iš serverio – fone, kai pasiekiama.
class GuideController extends AsyncNotifier<GuideBook> {
  @override
  Future<GuideBook> build() async {
    final repo = ref.watch(guideRepositoryProvider);
    final local = await repo.loadLocal();
    unawaited(_update(repo, local));
    return local;
  }

  Future<void> _update(GuideRepository repo, GuideBook current) async {
    final newer = await repo.fetchUpdate(current);
    if (newer != null && ref.mounted) state = AsyncData(newer);
  }
}

final guideProvider = AsyncNotifierProvider<GuideController, GuideBook>(GuideController.new);

/// Pažymėti kontrolinio sąrašo punktai (pvz., kas jau yra kuprinėje). Saugoma
/// įrenginyje pagal punkto tekstą – pakeitus gido versiją, žymės nepasislenka.
class GuideChecklistController extends Notifier<Set<String>> {
  GuideChecklistController(this.cardId);

  final String cardId;

  String get _key => 'guide_checklist_$cardId';

  @override
  Set<String> build() => {...?ref.watch(sharedPreferencesProvider).getStringList(_key)};

  Future<void> toggle(String item) async {
    final next = {...state};
    if (!next.remove(item)) next.add(item);
    state = next;
    await ref.read(sharedPreferencesProvider).setStringList(_key, next.toList());
  }
}

final guideChecklistProvider = NotifierProvider.family<GuideChecklistController, Set<String>, String>(
  GuideChecklistController.new,
);

/// Skambinimas / nuorodos atidarymas; testuose perrašoma.
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final emergencyNumber = Uri(scheme: 'tel', path: '112');
