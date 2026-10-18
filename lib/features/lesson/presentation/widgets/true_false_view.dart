import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';
import 'answer_colors.dart';
import 'lesson_image.dart';
import 'option_answer_state.dart';

/// `true_false`: teiginys ir du dideli mygtukai. Atsakymą laiko ir tikrina
/// pamokos ekranas; po „TIKRINTI“ ([locked]) teisingas mygtukas pažymimas žaliai.
class TrueFalseView extends StatelessWidget {
  const TrueFalseView({
    super.key,
    required this.item,
    required this.answer,
    required this.locked,
    required this.onAnswer,
  });

  final TrueFalseItem item;

  /// `null` – dar neatsakyta.
  final bool? answer;
  final bool locked;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    OptionAnswerState stateOf(bool value) => OptionAnswerState.resolve(
          selected: answer == value,
          isCorrectOption: item.correctAnswer == value,
          locked: locked,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        if (item.image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHigh,
                child: LessonImage(image: item.image),
              ),
            ),
          ),
        Text('Ar tai tiesa?', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        Text(item.prompt, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: _AnswerButton(
                label: 'Teisinga',
                icon: Icons.thumb_up_alt_outlined,
                state: stateOf(true),
                onTap: locked ? null : () => onAnswer(true),
              ),
            ),
            Expanded(
              child: _AnswerButton(
                label: 'Neteisinga',
                icon: Icons.thumb_down_alt_outlined,
                state: stateOf(false),
                onTap: locked ? null : () => onAnswer(false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.label, required this.icon, required this.state, this.onTap});

  final String label;
  final IconData icon;
  final OptionAnswerState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color border, double width, Color fill, IconData shownIcon, Color iconColor) = switch (state) {
      OptionAnswerState.idle => (scheme.outlineVariant, 1.0, scheme.surfaceContainerLow, icon, scheme.onSurfaceVariant),
      OptionAnswerState.selected => (scheme.primary, 3.0, scheme.primaryContainer, icon, scheme.primary),
      OptionAnswerState.correct || OptionAnswerState.missedCorrect =>
        (theme.correctColor, 3.0, scheme.surfaceContainerLow, Icons.check_circle, theme.correctColor),
      OptionAnswerState.wrong => (theme.incorrectColor, 3.0, scheme.surfaceContainerLow, Icons.cancel, theme.incorrectColor),
      OptionAnswerState.dimmed => (scheme.outlineVariant, 1.0, scheme.surfaceContainerLow, icon, scheme.onSurfaceVariant),
    };

    return Semantics(
      button: onTap != null,
      selected: state.isSelected,
      label: label,
      hint: state.semanticsHint,
      excludeSemantics: true,
      child: Opacity(
        opacity: state == OptionAnswerState.dimmed ? 0.5 : 1,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: width),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              child: Column(
                spacing: 8,
                children: [
                  Icon(shownIcon, size: 36, color: iconColor),
                  Text(label, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
