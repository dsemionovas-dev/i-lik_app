import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../application/guide_providers.dart';
import '../domain/guide.dart';

/// Atmintinės be žaidimo mechanikos: be paskyros, be interneto, be širdelių.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  final _search = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(guideProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gidas')),
      body: switch (guide) {
        AsyncData(:final value) => _content(value),
        AsyncError(:final error) => Center(child: Text('Nepavyko atidaryti gido: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _content(GuideBook book) {
    final theme = Theme.of(context);
    final cards = book.search(query: _search.text, categoryId: _categoryId);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _EmergencyCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            spacing: 6,
            children: [
              Icon(Icons.offline_pin_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
              Text(
                'Visos atmintinės veikia be interneto',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            key: const ValueKey('guide-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Paieška, pvz., „kraujavimas“',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Išvalyti',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Visos'),
                selected: _categoryId == null,
                onSelected: (_) => setState(() => _categoryId = null),
              ),
              for (final c in book.categories)
                ChoiceChip(
                  label: Text(c.title),
                  selected: _categoryId == c.id,
                  onSelected: (on) => setState(() => _categoryId = on ? c.id : null),
                ),
            ],
          ),
        ),
        if (cards.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Nieko nerasta. Pabandykite kitą žodį.', textAlign: TextAlign.center),
          ),
        for (final card in cards)
          ListTile(
            leading: Icon(_categoryIcon(book, card.categoryId)),
            title: Text(card.title),
            subtitle: Text(card.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.guideCard(card.id)),
          ),
      ],
    );
  }
}

IconData _categoryIcon(GuideBook book, String categoryId) {
  final icon = book.categories.where((c) => c.id == categoryId).firstOrNull?.icon;
  return switch (icon) {
    'warning' => Icons.warning_amber_rounded,
    'medical' => Icons.medical_services_outlined,
    'forest' => Icons.forest_outlined,
    _ => Icons.menu_book_outlined,
  };
}

/// Visada viršuje – krizės metu nereikia ieškoti.
class _EmergencyCard extends ConsumerWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.sos, color: scheme.onErrorContainer, size: 32),
        title: Text(
          'Skubi pagalba – 112',
          style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Nemokamai, visoje ES', style: TextStyle(color: scheme.onErrorContainer)),
        trailing: FilledButton.icon(
          key: const ValueKey('call-112'),
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => ref.read(urlOpenerProvider)(emergencyNumber),
          icon: const Icon(Icons.call),
          label: const Text('Skambinti'),
        ),
      ),
    );
  }
}
