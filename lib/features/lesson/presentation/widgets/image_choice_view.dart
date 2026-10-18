import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';
import 'answer_colors.dart';
import 'lesson_image.dart';
import 'option_answer_state.dart';

/// `image_choice`: paveikslėlių tinklelis. Pasirinkimą laiko ir tikrina pamokos
/// ekranas; po „TIKRINTI“ ([locked]) parodomas teisingas paveikslėlis.
class ImageChoiceView extends StatelessWidget {
  const ImageChoiceView({
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
    assert(item.choiceType == ChoiceType.image, 'ImageChoiceView tik image_choice tipui');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(item.prompt, style: Theme.of(context).textTheme.titleLarge),
        // Telefone – 2 stulpeliai, planšetėje daugiau; tėvinis ekranas jau slenka.
        GridView.extent(
          maxCrossAxisExtent: 220,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
          children: [
            for (final option in item.options)
              _ImageOptionTile(
                key: ValueKey(option.id),
                option: option,
                state: OptionAnswerState.of(item, option.id, selectedIds: selectedIds, locked: locked),
                onTap: locked ? null : () => onSelected(option.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _ImageOptionTile extends StatelessWidget {
  const _ImageOptionTile({super.key, required this.option, required this.state, this.onTap});

  final QuestionOption option;
  final OptionAnswerState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = option.image?.alt ?? option.text ?? option.id;

    final (Color border, double width, IconData? badge) = switch (state) {
      OptionAnswerState.idle => (scheme.outlineVariant, 1.0, null),
      OptionAnswerState.selected => (scheme.primary, 3.0, Icons.check_circle),
      OptionAnswerState.correct || OptionAnswerState.missedCorrect => (theme.correctColor, 3.0, Icons.check_circle),
      OptionAnswerState.wrong => (theme.incorrectColor, 3.0, Icons.cancel),
      OptionAnswerState.dimmed => (scheme.outlineVariant, 1.0, null),
    };
    final badgeColor = state == OptionAnswerState.selected ? scheme.primary : border;
    final radius = BorderRadius.circular(16);

    return Semantics(
      button: onTap != null,
      selected: state.isSelected,
      label: label,
      hint: state.semanticsHint,
      excludeSemantics: true,
      child: Opacity(
        opacity: state == OptionAnswerState.dimmed ? 0.5 : 1,
        child: Material(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: border, width: width),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: LessonImage(image: option.image)),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (badge != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                      child: Icon(badge, color: badgeColor, size: 28),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
