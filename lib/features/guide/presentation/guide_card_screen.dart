import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/guide_providers.dart';
import '../domain/guide.dart';

class GuideCardScreen extends ConsumerWidget {
  const GuideCardScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(guideProvider).value?.card(cardId);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(card?.title ?? 'Atmintinė')),
      body: card == null
          ? Center(
              child: ref.watch(guideProvider).isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Atmintinė nerasta.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(card.summary, style: theme.textTheme.titleMedium),
                if (card.emergencyCall) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('card-call-112'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () => ref.read(urlOpenerProvider)(emergencyNumber),
                    icon: const Icon(Icons.call),
                    label: const Text('Skambinti 112'),
                  ),
                ],
                for (final block in card.blocks) ...[
                  const SizedBox(height: 20),
                  if (block.heading != null) ...[
                    Text(block.heading!, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                  ],
                  _Block(cardId: card.id, block: block),
                ],
                const SizedBox(height: 24),
                const Divider(),
                Text(
                  'Atmintinė nepakeičia praktinių mokymų. Pavojuje – skambinkite 112.',
                  style: theme.textTheme.bodySmall,
                ),
                if (card.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Šaltiniai', style: theme.textTheme.labelLarge),
                  for (final s in card.sources)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.title),
                      subtitle: s.url == null ? null : Text(s.url!),
                      onTap: s.url == null ? null : () => ref.read(urlOpenerProvider)(Uri.parse(s.url!)),
                    ),
                ],
              ],
            ),
    );
  }
}

class _Block extends ConsumerWidget {
  const _Block({required this.cardId, required this.block});

  final String cardId;
  final GuideBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;
    switch (block.kind) {
      case GuideBlockKind.text:
        return Text(block.text ?? '', style: body);
      case GuideBlockKind.warning:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
              Expanded(
                child: Text(block.text ?? '', style: body?.copyWith(color: theme.colorScheme.onErrorContainer)),
              ),
            ],
          ),
        );
      case GuideBlockKind.steps:
        return Column(
          spacing: 10,
          children: [
            for (final (i, item) in block.items.indexed)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  CircleAvatar(radius: 13, child: Text('${i + 1}', style: theme.textTheme.labelMedium)),
                  Expanded(child: Text(item, style: body)),
                ],
              ),
          ],
        );
      case GuideBlockKind.bullets:
        return Column(
          spacing: 8,
          children: [
            for (final item in block.items)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [Text('•', style: body), Expanded(child: Text(item, style: body))],
              ),
          ],
        );
      case GuideBlockKind.checklist:
        final checked = ref.watch(guideChecklistProvider(cardId));
        final done = block.items.where(checked.contains).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Turite: $done iš ${block.items.length}', key: const ValueKey('checklist-progress')),
            for (final item in block.items)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: checked.contains(item),
                title: Text(item),
                onChanged: (_) => ref.read(guideChecklistProvider(cardId).notifier).toggle(item),
              ),
          ],
        );
    }
  }
}
