import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../auth/presentation/account_section.dart';
import '../../progress/application/progress_controller.dart';
import '../../progress/application/progress_service.dart';

/// TODO: XP grafikas, kursų progresas, ženkleliai, lyga.
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
        onRefresh: () => ref.read(progressControllerProvider.notifier).syncNow(),
        child: ListView(
          children: [
            if (progress != null) _Stats(progress: progress),
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
              Expanded(child: _StatTile(value: '${progress.totalXp}', label: 'XP')),
              Expanded(child: _StatTile(value: '${progress.completedLessons}', label: 'Baigtos pamokos')),
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
