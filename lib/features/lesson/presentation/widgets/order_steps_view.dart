import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';
import 'answer_colors.dart';

/// „Sudėliok tvarką“: vartotojas tempia žingsnius. Atsakymą tikrina pamokos
/// ekranas (TIKRINTI), šis valdiklis tik praneša dabartinę tvarką.
class OrderStepsView extends StatefulWidget {
  const OrderStepsView({
    super.key,
    required this.item,
    required this.locked,
    required this.onOrderChanged,
    this.random,
  });

  final OrderStepsItem item;

  /// Po „TIKRINTI“ tempti nebegalima.
  final bool locked;
  final ValueChanged<List<String>> onOrderChanged;

  /// Testams – deterministiniam maišymui.
  final Random? random;

  @override
  State<OrderStepsView> createState() => _OrderStepsViewState();
}

class _OrderStepsViewState extends State<OrderStepsView> {
  late final List<OrderStep> _steps = _shuffled();

  @override
  void initState() {
    super.initState();
    // Pradinė tvarka irgi yra atsakymas – ekranas turi ją žinoti iškart.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  /// Sumaišo taip, kad pradinė tvarka niekada nebūtų teisinga.
  List<OrderStep> _shuffled() {
    final steps = [...widget.item.steps];
    if (steps.length < 2) return steps;
    do {
      steps.shuffle(widget.random);
    } while (widget.item.isCorrect([for (final s in steps) s.id]));
    return steps;
  }

  void _notify() {
    if (mounted) widget.onOrderChanged([for (final s in _steps) s.id]);
  }

  /// `onReorderItem` jau pakoreguoja [newIndex] pašalintam elementui.
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      _steps.insert(newIndex, _steps.removeAt(oldIndex));
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ids = [for (final s in _steps) s.id];
    // Po „TIKRINTI“ ([locked]) atskleidžiama, kurios pozicijos teisingos.
    final reveal = widget.locked;
    final allCorrect = widget.item.isCorrect(ids);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(widget.item.prompt, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        // Tėvinis ekranas jau slenka, todėl sąrašas be savo slinkties.
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _steps.length,
          onReorderItem: widget.locked ? (_, _) {} : _reorder,
          itemBuilder: (context, index) {
            final step = _steps[index];
            final inPlace = widget.item.correctOrder.elementAtOrNull(index) == step.id;
            return Card(
              key: ValueKey(step.id),
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: reveal
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: inPlace ? theme.correctColor : theme.incorrectColor, width: 2),
                    )
                  : null,
              child: ListTile(
                leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
                title: Text(step.text),
                trailing: reveal
                    ? Icon(
                        inPlace ? Icons.check_circle : Icons.cancel,
                        color: inPlace ? theme.correctColor : theme.incorrectColor,
                        semanticLabel: inPlace ? 'Teisingoje vietoje' : 'Ne savo vietoje',
                      )
                    : ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle, semanticLabel: 'Tempti'),
                      ),
              ),
            );
          },
        ),
        if (reveal && !allCorrect) _CorrectOrder(item: widget.item),
      ],
    );
  }
}

/// Teisinga seka, rodoma po neteisingo atsakymo.
class _CorrectOrder extends StatelessWidget {
  const _CorrectOrder({required this.item});

  final OrderStepsItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textById = {for (final s in item.steps) s.id: s.text};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.correctColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text('Teisinga tvarka', style: theme.textTheme.titleSmall?.copyWith(color: theme.correctColor)),
          for (final (i, id) in item.correctOrder.indexed)
            Text('${i + 1}. ${textById[id] ?? id}', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
