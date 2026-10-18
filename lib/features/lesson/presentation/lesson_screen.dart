import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../progress/application/progress_controller.dart';
import '../data/lesson_repository.dart';
import '../domain/models/lesson.dart';
import '../domain/models/lesson_result.dart';
import 'widgets/answer_colors.dart';
import 'widgets/lesson_item_view.dart';

class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonProvider(lessonId));
    return lesson.when(
      data: (lesson) => _LessonRunner(lesson: lesson),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Nepavyko įkelti pamokos.\n$e', textAlign: TextAlign.center)),
      ),
    );
  }
}

/// Pamokos eiga: užduotis → TIKRINTI → atsiliepimas → TĘSTI.
/// Vėliau logiką verta perkelti į `application/lesson_session_controller.dart` (Notifier).
class _LessonRunner extends ConsumerStatefulWidget {
  const _LessonRunner({required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<_LessonRunner> createState() => _LessonRunnerState();
}

class _LessonRunnerState extends ConsumerState<_LessonRunner> {
  late final List<LessonItem> _items = widget.lesson.playableItems;
  final _startedAt = DateTime.now();
  final _answers = <bool>[];
  final _gradedItems = <LessonItem>[];

  var _index = 0;
  var _selected = <String>{};
  var _order = <String>[];
  var _matches = <String, String>{};
  bool? _trueFalse;
  Offset? _hotspot;
  bool? _lastCorrect; // null – dar netikrinta
  var _leaving = false;

  LessonItem get _item => _items[_index];

  /// Teorijos kortelė (ir nežinomi tipai) atsakymo nereikalauja.
  bool get _needsAnswer => _item.isGraded;

  bool get _hasAnswer => switch (_item) {
        ChoiceItem() => _selected.isNotEmpty,
        OrderStepsItem() => _order.isNotEmpty,
        // Tikrinti galima tik sujungus visas poras.
        MatchPairsItem(:final pairs) => _matches.length == pairs.length,
        TrueFalseItem() => _trueFalse != null,
        HotspotItem() => _hotspot != null,
        _ => false,
      };

  void _toggle(String optionId) {
    final item = _item as ChoiceItem;
    setState(() {
      _selected = item.allowsMultiple
          ? ({..._selected}..toggle(optionId))
          : {optionId};
    });
  }

  void _check() {
    final item = _item;
    final correct = switch (item) {
      ChoiceItem() => item.isCorrect(_selected),
      OrderStepsItem() => item.isCorrect(_order),
      MatchPairsItem() => item.isCorrect(_matches),
      TrueFalseItem() => item.isCorrect(_trueFalse!),
      HotspotItem() => item.isCorrect(_hotspot!.dx, _hotspot!.dy),
      _ => throw StateError('Užduotis ${item.type} nevertinama'),
    };
    setState(() {
      _lastCorrect = correct;
      _answers.add(correct);
      _gradedItems.add(item);
    });
  }

  void _next() {
    if (_index + 1 < _items.length) {
      setState(() {
        _index++;
        _selected = {};
        _order = [];
        _matches = {};
        _trueFalse = null;
        _hotspot = null;
        _lastCorrect = null;
      });
      return;
    }
    final result = LessonResult(
      lessonId: widget.lesson.id,
      correctCount: _answers.where((a) => a).length,
      gradedCount: _answers.length,
      xpEarned: LessonResult.calculateXp(
        lesson: widget.lesson,
        answers: _answers,
        gradedItems: _gradedItems,
      ),
      duration: DateTime.now().difference(_startedAt),
    );
    // Vietinis įrašas + siuntimas fone; rezultatų ekranas nelaukia tinklo.
    unawaited(ref.read(progressControllerProvider.notifier).recordLessonResult(widget.lesson, result));
    context.pushReplacement(Routes.lessonResult(widget.lesson.id), extra: result);
  }

  Future<void> _confirmClose() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nutraukti pamoką?'),
        content: const Text('Progresas šioje pamokoje bus prarastas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tęsti')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nutraukti')),
        ],
      ),
    );
    if (!(leave ?? false) || !mounted) return;
    // PopScope perskaitomas tik po perstatymo, todėl pop – kitame kadre.
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final checked = _lastCorrect != null;
    final item = _item;
    final feedback = switch (item) {
      ChoiceItem(:final feedback) ||
      OrderStepsItem(:final feedback) ||
      MatchPairsItem(:final feedback) ||
      TrueFalseItem(:final feedback) ||
      HotspotItem(:final feedback) =>
        feedback,
      _ => ItemFeedback.empty,
    };

    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _confirmClose),
          actions: [
            IconButton(
              tooltip: 'Pranešti apie klaidą',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => context.push(Routes.report(lessonId: widget.lesson.id, itemId: item.id)),
            ),
          ],
          title: LinearProgressIndicator(value: (_index + (checked ? 1 : 0)) / _items.length),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: LessonItemView(
                      item: item,
                      selectedIds: _selected,
                      locked: checked,
                      onToggleOption: _toggle,
                      onOrderChanged: (ids) => setState(() => _order = ids),
                      onMatchesChanged: (m) => setState(() => _matches = m),
                      trueFalseAnswer: _trueFalse,
                      onTrueFalse: (v) => setState(() => _trueFalse = v),
                      hotspotTap: _hotspot,
                      onHotspotTap: (p) => setState(() => _hotspot = p),
                    ),
                  ),
                ),
                if (checked)
                  _FeedbackBanner(
                    correct: _lastCorrect!,
                    message: _lastCorrect! ? feedback.correct : feedback.incorrect,
                  ),
                const SizedBox(height: 12),
                if (_needsAnswer && !checked)
                  FilledButton(
                    onPressed: _hasAnswer ? _check : null,
                    child: const Text('TIKRINTI'),
                  )
                else
                  FilledButton(
                    onPressed: _next,
                    child: Text(item is InfoCardItem ? 'SUPRATAU' : 'TĘSTI'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.correct, this.message});

  final bool correct;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? Theme.of(context).correctColor.withValues(alpha: 0.15) : scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        [correct ? 'Teisingai!' : 'Neteisingai', ?message].join('\n'),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

extension on Set<String> {
  void toggle(String value) => contains(value) ? remove(value) : add(value);
}
