import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';
import 'answer_colors.dart';
import 'lesson_image.dart';
import 'option_answer_state.dart';

/// `scenario`: situacija ir keli keliai. Po „TIKRINTI“ ([locked]) po pasirinktu
/// keliu parodoma jo pasekmė (`outcome`), o jei pasirinkta klaidingai – ir
/// teisingo kelio pasekmė, kad vartotojas matytų skirtumą.
class ScenarioView extends StatelessWidget {
  const ScenarioView({
    super.key,
    required this.item,
    required this.selectedIds,
    required this.locked,
    required this.onSelected,
  });

  final ChoiceItem item;
  final Set<String> selectedIds;
  final bool locked;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    assert(item.choiceType == ChoiceType.scenario, 'ScenarioView tik scenario tipui');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        if (item.image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            // Fiksuotas aukštis: telefone ≈ 16:9, planšetėje nenustumia variantų žemyn.
            child: SizedBox(
              height: 180,
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHigh,
                child: LessonImage(image: item.image),
              ),
            ),
          ),
        Text(item.prompt, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        for (final option in item.options)
          _ScenarioOptionCard(
            key: ValueKey(option.id),
            option: option,
            state: OptionAnswerState.of(item, option.id, selectedIds: selectedIds, locked: locked),
            onTap: locked ? null : () => onSelected(option.id),
          ),
      ],
    );
  }
}

class _ScenarioOptionCard extends StatelessWidget {
  const _ScenarioOptionCard({super.key, required this.option, required this.state, this.onTap});

  final QuestionOption option;
  final OptionAnswerState state;
  final VoidCallback? onTap;

  /// Pasekmė rodoma pasirinktam keliui ir praleistam teisingam keliui.
  bool get _showsOutcome =>
      option.outcome != null &&
      switch (state) {
        OptionAnswerState.correct || OptionAnswerState.wrong || OptionAnswerState.missedCorrect => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color border, double width, IconData icon, Color iconColor) = switch (state) {
      OptionAnswerState.idle => (scheme.outlineVariant, 1.0, Icons.radio_button_unchecked, scheme.outline),
      OptionAnswerState.selected => (scheme.primary, 2.5, Icons.radio_button_checked, scheme.primary),
      OptionAnswerState.correct ||
      OptionAnswerState.missedCorrect => (theme.correctColor, 2.5, Icons.check_circle, theme.correctColor),
      OptionAnswerState.wrong => (theme.incorrectColor, 2.5, Icons.cancel, theme.incorrectColor),
      OptionAnswerState.dimmed => (scheme.outlineVariant, 1.0, Icons.radio_button_unchecked, scheme.outline),
    };

    return Semantics(
      button: onTap != null,
      selected: state.isSelected,
      hint: state.semanticsHint,
      child: Opacity(
        opacity: state == OptionAnswerState.dimmed ? 0.5 : 1,
        child: Material(
          color: state == OptionAnswerState.selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: width),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Icon(icon, color: iconColor),
                      Expanded(child: Text(option.text ?? option.id, style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                  // Pasekmė „išsiskleidžia“ po patikrinimo.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: _showsOutcome
                        ? _Outcome(
                            title: state == OptionAnswerState.missedCorrect ? 'Teisingas kelias' : 'Pasekmė',
                            text: option.outcome!,
                            color: border,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.title, required this.text, required this.color});

  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 36),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(title, style: textTheme.labelLarge?.copyWith(color: color)),
          Text(text, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
