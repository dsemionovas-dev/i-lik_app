import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/account_section.dart';
import '../../badges/application/badge_controller.dart';
import '../../badges/domain/badge.dart';
import '../../badges/presentation/badges_section.dart';
import '../application/profile_controller.dart';
import '../../leagues/data/league_repository.dart';
import '../../progress/application/progress_controller.dart';
import '../../progress/application/progress_service.dart';

/// TODO: XP grafikas, kursų progresas.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressControllerProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilis'),
        actions: [
          IconButton(
            tooltip: 'Nustatymai',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(progressControllerProvider.notifier).syncNow();
          ref
            ..invalidate(leagueProvider)
            ..invalidate(serverBadgesProvider)
            ..invalidate(profileControllerProvider);
        },
        child: ListView(
          children: [
            const _ProfileHeader(),
            if (progress != null) _Stats(progress: progress),
            const _LeagueCard(),
            const BadgesSection(),
            const AccountSection(),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.progress});

  final ProgressState progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offline = progress.lastSync?.status == SyncStatus.offline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(value: '${progress.totalXp}', label: 'XP'),
              ),
              Expanded(
                child: _StatTile(
                  value: '${Streak.of(progress.activityDays, today: DateTime.now()).current}',
                  label: 'Serija (d.)',
                ),
              ),
              Expanded(
                child: _StatTile(value: '${progress.completedLessons}', label: 'Baigtos pamokos'),
              ),
            ],
          ),
          if (progress.syncEnabled && progress.pending > 0)
            Text(
              offline
                  ? 'Laukia išsiuntimo: ${progress.pending} (nėra ryšio)'
                  : 'Laukia išsiuntimo: ${progress.pending}',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value, style: text.headlineMedium),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Lyga trumpai; paspaudus – visa lentelė.
class _LeagueCard extends ConsumerWidget {
  const _LeagueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(leagueRepositoryProvider) == null) return const SizedBox.shrink();
    final league = ref.watch(leagueProvider);
    final subtitle = switch (league) {
      AsyncData(value: final s?) when s.me != null => '${s.me!.rank} vieta · ${s.me!.weeklyXp} XP šią savaitę',
      AsyncData(value: _?) => 'Užbaik pamoką, kad prisijungtum',
      AsyncError() => 'Nepavyko įkelti',
      _ => '…',
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        key: const ValueKey('league-card'),
        leading: const Icon(Icons.emoji_events_outlined),
        title: Text(league.value == null ? 'Lyga' : '${league.value!.tierName} lyga'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(Routes.league),
      ),
    );
  }
}

/// Avataras, vardas ir „Redaguoti“.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider).value;
    final user = ref.watch(authStateProvider).value;
    if (state == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          state.profile.avatarEmoji,
          key: const ValueKey('profile-avatar'),
          style: const TextStyle(fontSize: 28),
        ),
      ),
      title: Text(state.displayName, key: const ValueKey('profile-name'), style: theme.textTheme.titleLarge),
      subtitle: Text(user == null ? 'Neprisijungta' : (user.isAnonymous ? 'Svečias' : user.email ?? '')),
      trailing: state.userId == null
          ? null
          : IconButton(
              tooltip: 'Redaguoti profilį',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go(Routes.editProfile),
            ),
    );
  }
}
