import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../badges/presentation/badges_section.dart';
import '../../progress/application/progress_controller.dart';
import '../domain/models/lesson_result.dart';

class LessonResultScreen extends ConsumerWidget {
  const LessonResultScreen({super.key, required this.lessonId, this.result});

  final String lessonId;

  /// `null`, jei ekranas atkurtas be `extra` (pvz., po proceso sustabdymo).
  final LessonResult? result;

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(Routes.home);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result;
    final progress = ref.watch(progressControllerProvider).value;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('Pamoka baigta!', style: text.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (r != null) ...[
                Text('★' * r.stars + '☆' * (3 - r.stars),
                    style: text.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text('+${r.xpEarned} XP', style: text.headlineSmall, textAlign: TextAlign.center),
                Text('Tikslumas: ${(r.accuracy * 100).round()} %',
                    style: text.titleMedium, textAlign: TextAlign.center),
              ],
              if (r != null) ...[
                const SizedBox(height: 24),
                NewBadgesNote(since: r.startedAt),
              ],
              if (progress != null) ...[
                const SizedBox(height: 24),
                _SyncNote(progress: progress),
              ],
              const Spacer(),
              FilledButton(onPressed: () => _close(context), child: const Text('TĘSTI')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncNote extends StatelessWidget {
  const _SyncNote({required this.progress});

  final ProgressState progress;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = !progress.syncEnabled
        ? (Icons.phone_android, 'Progresas išsaugotas šiame įrenginyje.')
        : progress.pending > 0
            ? (Icons.cloud_upload_outlined, 'Progresas išsaugotas įrenginyje ir bus išsiųstas, kai atsiras ryšys.')
            : (Icons.cloud_done_outlined, 'Progresas išsaugotas.');
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: color),
        Flexible(child: Text(text, style: TextStyle(color: color), textAlign: TextAlign.center)),
      ],
    );
  }
}
