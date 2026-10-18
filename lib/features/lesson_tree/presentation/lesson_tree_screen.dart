import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../lesson/data/lesson_repository.dart';
import '../../lesson/domain/models/catalog.dart';
import '../../progress/application/progress_controller.dart';
import '../../progress/domain/models/user_progress.dart';

/// Kursai → skyriai → pamokos iš turinio katalogo (serveris, kešas arba assets).
/// TODO: vingiuotas kelias su mazgų būsenomis (užrakinta / aktyvi / baigta / auksinė).
class LessonTreeScreen extends ConsumerWidget {
  const LessonTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelias')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(catalogProvider.future),
        child: catalog.when(
          data: (catalog) => _CatalogList(
            catalog: catalog,
            progress: ref.watch(progressControllerProvider).value?.progress ?? const {},
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('Nepavyko įkelti kurso turinio.\n$e', textAlign: TextAlign.center)],
          ),
        ),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.catalog, required this.progress});

  final ContentCatalog catalog;
  final Map<String, UserProgress> progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      children: [
        if (catalog.source != ContentSource.remote) const _OfflineBanner(),
        for (final course in catalog.courses) ...[
          ListTile(
            title: Text(course.title, style: text.titleLarge),
            subtitle: course.description == null ? null : Text(course.description!),
          ),
          if (catalog.unitsOf(course.id).isEmpty)
            const ListTile(
              dense: true,
              leading: Icon(Icons.cloud_download_outlined),
              title: Text('Pamokos bus atsisiųstos prisijungus prie interneto'),
            ),
          for (final unit in catalog.unitsOf(course.id)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(unit.title, style: text.titleSmall),
            ),
            for (final lesson in catalog.lessonsOf(unit.id))
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(lesson.title),
                subtitle: Text('${lesson.estimatedMinutes} min'),
                trailing: _stars(progress[lesson.id]),
                onTap: () => context.push(Routes.lesson(lesson.id)),
              ),
          ],
          const Divider(),
        ],
      ],
    );
  }
}

/// Baigtos pamokos žvaigždutės; nebaigtai – nieko.
Widget? _stars(UserProgress? p) => p == null || !p.isCompleted
    ? null
    : Text('★' * p.stars + '☆' * (3 - p.stars), semanticsLabel: '${p.stars} iš 3 žvaigždučių');

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(Icons.cloud_off, color: scheme.onSecondaryContainer),
          Expanded(
            child: Text(
              'Nėra ryšio su serveriu – rodomas išsaugotas turinys.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
