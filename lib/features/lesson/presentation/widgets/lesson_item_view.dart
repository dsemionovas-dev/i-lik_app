import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';
import 'hotspot_view.dart';
import 'image_choice_view.dart';
import 'match_pairs_view.dart';
import 'order_steps_view.dart';
import 'scenario_view.dart';
import 'true_false_view.dart';

/// Atvaizduoja vieną užduotį. Išsamus `switch` per `sealed` klasę –
/// pridėjus naują tipą, kompiliatorius parodys, kur trūksta UI.
class LessonItemView extends StatelessWidget {
  const LessonItemView({
    super.key,
    required this.item,
    required this.selectedIds,
    required this.locked,
    required this.onToggleOption,
    required this.onOrderChanged,
    required this.onMatchesChanged,
    this.trueFalseAnswer,
    required this.onTrueFalse,
    this.hotspotTap,
    required this.onHotspotTap,
  });

  final LessonItem item;
  final Set<String> selectedIds;

  /// Po „TIKRINTI“ atsakymo keisti nebegalima.
  final bool locked;
  final ValueChanged<String> onToggleOption;
  final ValueChanged<List<String>> onOrderChanged;
  final ValueChanged<Map<String, String>> onMatchesChanged;
  final bool? trueFalseAnswer;
  final ValueChanged<bool> onTrueFalse;
  final Offset? hotspotTap;
  final ValueChanged<Offset> onHotspotTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return switch (item) {
      InfoCardItem(:final title, :final body) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [Text(title, style: text.headlineSmall), Text(body, style: text.bodyLarge)],
        ),
      final ChoiceItem choice when choice.choiceType == ChoiceType.image => ImageChoiceView(
          item: choice,
          selectedIds: selectedIds,
          locked: locked,
          onSelected: onToggleOption,
        ),
      final ChoiceItem choice when choice.choiceType == ChoiceType.scenario => ScenarioView(
          item: choice,
          selectedIds: selectedIds,
          locked: locked,
          onSelected: onToggleOption,
        ),
      ChoiceItem(:final prompt, :final options) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(prompt, style: text.titleLarge),
            const SizedBox(height: 8),
            for (final o in options)
              _OptionTile(
                label: o.text ?? o.image?.alt ?? o.id,
                selected: selectedIds.contains(o.id),
                onTap: locked ? null : () => onToggleOption(o.id),
              ),
          ],
        ),
      // Raktas pagal id: dvi iš eilės einančios užduotys nesidalija būsena.
      final OrderStepsItem steps => OrderStepsView(
          key: ValueKey(steps.id),
          item: steps,
          locked: locked,
          onOrderChanged: onOrderChanged,
        ),
      final MatchPairsItem pairs => MatchPairsView(
          key: ValueKey(pairs.id),
          item: pairs,
          locked: locked,
          onMatchesChanged: onMatchesChanged,
        ),
      final TrueFalseItem tf => TrueFalseView(
          item: tf,
          answer: trueFalseAnswer,
          locked: locked,
          onAnswer: onTrueFalse,
        ),
      final HotspotItem hotspot => HotspotView(
          item: hotspot,
          tap: hotspotTap,
          locked: locked,
          onTap: onHotspotTap,
        ),
      UnsupportedItem() => const SizedBox.shrink(),
    };
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        backgroundColor: selected ? scheme.primaryContainer : null,
        side: BorderSide(color: selected ? scheme.primary : scheme.outline, width: selected ? 2 : 1),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}
