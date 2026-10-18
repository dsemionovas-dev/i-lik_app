import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/badge_controller.dart';
import '../domain/badge.dart';
import 'badge_icon.dart';

String formatDate(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

/// Ženklelių tinklelis profilyje: gauti spalvoti, negauti – pilki su sąlyga ir progresu.
class BadgesSection extends ConsumerWidget {
  const BadgesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(badgeControllerProvider).value;
    if (state == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'Ženkleliai · ${state.earned.length} iš ${state.definitions.length}',
            style: theme.textTheme.titleMedium,
          ),
          GridView.extent(
            maxCrossAxisExtent: 110,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
            children: [for (final d in state.definitions) _BadgeTile(definition: d, state: state)],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.definition, required this.state});

  final BadgeDefinition definition;
  final BadgeState state;

  @override
  Widget build(BuildContext context) {
    final earnedAt = state.earned[definition.id];
    final earned = earnedAt != null;
    final p = definition.rule.progress(state.stats);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${definition.title}, ${earned ? 'gautas' : 'negautas: ${definition.description}'}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('badge-${definition.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(context, earnedAt, p),
        child: Column(
          spacing: 6,
          children: [
            BadgeMedal(icon: definition.icon, earned: earned),
            Text(
              definition.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: earned ? null : theme.colorScheme.outline),
            ),
            if (!earned && p.target > 1)
              Text('${p.current.clamp(0, p.target)} / ${p.target}', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, DateTime? earnedAt, ({int current, int target}) p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            BadgeMedal(icon: definition.icon, earned: earnedAt != null, size: 80),
            Text(definition.title, style: Theme.of(context).textTheme.titleLarge),
            Text(definition.description, textAlign: TextAlign.center),
            Text(
              earnedAt != null
                  ? 'Gautas ${formatDate(earnedAt)}'
                  : p.target > 0
                  ? 'Progresas: ${p.current.clamp(0, p.target)} / ${p.target}'
                  : 'Dar negautas',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Rezultatų ekranui: per pamoką gauti ženkleliai.
class NewBadgesNote extends ConsumerWidget {
  const NewBadgesNote({super.key, required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fresh = ref.watch(badgeControllerProvider).value?.earnedSince(since) ?? const [];
    if (fresh.isEmpty) return const SizedBox.shrink();
    return Column(
      spacing: 8,
      children: [
        Text(
          fresh.length == 1 ? 'Naujas ženklelis!' : 'Nauji ženkleliai!',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final b in fresh)
              Column(
                key: ValueKey('new-badge-${b.id}'),
                spacing: 4,
                children: [
                  BadgeMedal(icon: b.icon, earned: true),
                  Text(b.title),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
