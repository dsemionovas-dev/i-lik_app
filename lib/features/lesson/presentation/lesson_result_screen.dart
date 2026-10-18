import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../domain/models/lesson_result.dart';

class LessonResultScreen extends StatelessWidget {
  const LessonResultScreen({super.key, required this.lessonId, this.result});

  final String lessonId;

  /// `null`, jei ekranas atkurtas be `extra` (pvz., po proceso sustabdymo).
  final LessonResult? result;

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(Routes.home);

  @override
  Widget build(BuildContext context) {
    final r = result;
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
              const Spacer(),
              FilledButton(onPressed: () => _close(context), child: const Text('TĘSTI')),
            ],
          ),
        ),
      ),
    );
  }
}
