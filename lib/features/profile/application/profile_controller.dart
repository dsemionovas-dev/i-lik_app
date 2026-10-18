import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../leagues/data/league_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseProfileRemoteDataSource(client);
});

class ProfileState {
  const ProfileState({required this.userId, required this.profile});

  final String? userId;
  final Profile profile;

  String get displayName => userId == null ? 'Svečias' : profile.nameFor(userId!);
}

/// Profilis: vietinė kopija iškart, serverio versija – kai pasiekiama.
class ProfileController extends AsyncNotifier<ProfileState> {
  LocalProfileStore get _local => LocalProfileStore(ref.read(sharedPreferencesProvider));

  @override
  Future<ProfileState> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return const ProfileState(userId: null, profile: Profile());
    final local = _local.read(user.id);
    final remote = ref.watch(profileRemoteDataSourceProvider);
    if (remote != null) {
      try {
        final fromServer = await remote.fetch(user.id);
        if (fromServer != null) {
          await _local.write(user.id, fromServer);
          return ProfileState(userId: user.id, profile: fromServer);
        }
      } on Object {
        // Be ryšio – vietinė kopija.
      }
    }
    return ProfileState(userId: user.id, profile: local ?? const Profile());
  }

  /// Išsaugo vardą ir avatarą. Klaida – vartotojui rodomas tekstas.
  Future<void> save({required String displayName, required String avatar}) async {
    // Tarpus sutvarkom patys – vartotojo už tai nebaudžiam.
    final name = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final error = validateDisplayName(name);
    if (error != null) throw ProfileFailure(error);
    if (!avatars.containsKey(avatar)) throw const ProfileFailure('Pasirinkite avatarą.');

    final user = ref.read(authRepositoryProvider).currentUser ?? await _ensureUser();
    final profile = Profile(displayName: name, avatar: avatar);
    final remote = ref.read(profileRemoteDataSourceProvider);
    if (remote != null) {
      try {
        await remote.save(user.id, profile);
      } on Object {
        throw const ProfileFailure('Nepavyko išsaugoti – patikrinkite interneto ryšį.');
      }
    }
    await _local.write(user.id, profile);
    state = AsyncData(ProfileState(userId: user.id, profile: profile));
    // Vardas lygoje pasikeičia (serveryje – trigeris).
    ref.invalidate(leagueProvider);
  }

  Future<AppUser> _ensureUser() async {
    try {
      return await ref.read(authRepositoryProvider).ensureSignedIn();
    } on Object {
      throw const ProfileFailure('Nepavyko išsaugoti – patikrinkite interneto ryšį.');
    }
  }
}

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, ProfileState>(ProfileController.new);
