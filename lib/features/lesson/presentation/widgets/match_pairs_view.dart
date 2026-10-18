import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';
import 'answer_colors.dart';

/// `match_pairs`: paspaudus elementą viename stulpelyje ir tada kitame, jie
/// sujungiami (abu gauna tą patį poros numerį). Paspaudus sujungtą elementą,
/// pora išardoma. Tikrina pamokos ekranas; po „TIKRINTI“ ([locked]) poros
/// nuspalvinamos, o klaidingoms parodomas teisingas atitikmuo.
class MatchPairsView extends StatefulWidget {
  const MatchPairsView({
    super.key,
    required this.item,
    required this.locked,
    required this.onMatchesChanged,
    this.random,
  });

  final MatchPairsItem item;
  final bool locked;

  /// Kairė pusė → pasirinkta dešinė pusė (kaip [MatchPairsItem.isCorrect]).
  final ValueChanged<Map<String, String>> onMatchesChanged;

  /// Testams – deterministiniam maišymui.
  final Random? random;

  @override
  State<MatchPairsView> createState() => _MatchPairsViewState();
}

class _MatchPairsViewState extends State<MatchPairsView> {
  late final List<String> _lefts = [for (final p in widget.item.pairs) p.left];
  late final List<String> _rights = _shuffledRights();
  late final Map<String, String> _correct = {for (final p in widget.item.pairs) p.left: p.right};

  final _matches = <String, String>{};
  String? _activeLeft;
  String? _activeRight;

  /// Dešinysis stulpelis niekada nesutampa su kairiuoju eilė į eilę.
  List<String> _shuffledRights() {
    final rights = [for (final p in widget.item.pairs) p.right];
    if (rights.length < 2) return rights;
    final aligned = [...rights];
    do {
      rights.shuffle(widget.random);
    } while (_sameOrder(rights, aligned));
    return rights;
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String? _leftOf(String right) {
    for (final MapEntry(:key, :value) in _matches.entries) {
      if (value == right) return key;
    }
    return null;
  }

  /// Poros numeris (1…n) pagal kairiojo elemento eilę.
  int? _pairNumber({String? left, String? right}) {
    final l = left ?? (right == null ? null : _leftOf(right));
    if (l == null || !_matches.containsKey(l)) return null;
    return _lefts.indexOf(l) + 1;
  }

  void _tapLeft(String left) {
    setState(() {
      if (_matches.remove(left) != null) {
        _activeLeft = left;
        _activeRight = null;
      } else if (_activeRight != null) {
        _pair(left, _activeRight!);
      } else {
        _activeLeft = _activeLeft == left ? null : left;
      }
    });
    _notify();
  }

  void _tapRight(String right) {
    setState(() {
      final pairedLeft = _leftOf(right);
      if (pairedLeft != null) {
        _matches.remove(pairedLeft);
        _activeRight = right;
        _activeLeft = null;
      } else if (_activeLeft != null) {
        _pair(_activeLeft!, right);
      } else {
        _activeRight = _activeRight == right ? null : right;
      }
    });
    _notify();
  }

  void _pair(String left, String right) {
    _matches[left] = right;
    _activeLeft = null;
    _activeRight = null;
  }

  void _notify() => widget.onMatchesChanged(Map.unmodifiable(_matches));

  _TileState _stateOf({required bool active, required String? left}) {
    if (left == null || !_matches.containsKey(left)) {
      return active ? _TileState.active : _TileState.idle;
    }
    if (!widget.locked) return _TileState.matched;
    return _matches[left] == _correct[left] ? _TileState.correct : _TileState.wrong;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wrongLefts = widget.locked
        ? [for (final l in _lefts) if (_matches[l] != _correct[l]) l]
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(widget.item.prompt, style: theme.textTheme.titleLarge),
        if (!widget.locked)
          Text(
            'Paspausk elementą kairėje, tada jo porą dešinėje.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        const SizedBox(height: 4),
        for (var i = 0; i < _lefts.length; i++)
          // Eilutė – vienodo aukščio kairė ir dešinė kortelės.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Expanded(
                  child: _PairTile(
                    key: ValueKey('L:${_lefts[i]}'),
                    text: _lefts[i],
                    number: _pairNumber(left: _lefts[i]),
                    partner: _matches[_lefts[i]],
                    state: _stateOf(active: _activeLeft == _lefts[i], left: _lefts[i]),
                    onTap: widget.locked ? null : () => _tapLeft(_lefts[i]),
                  ),
                ),
                Expanded(
                  child: _PairTile(
                    key: ValueKey('R:${_rights[i]}'),
                    text: _rights[i],
                    number: _pairNumber(right: _rights[i]),
                    partner: _leftOf(_rights[i]),
                    state: _stateOf(active: _activeRight == _rights[i], left: _leftOf(_rights[i])),
                    onTap: widget.locked ? null : () => _tapRight(_rights[i]),
                  ),
                ),
              ],
            ),
          ),
        if (wrongLefts.isNotEmpty) _CorrectPairs(lefts: wrongLefts, correct: _correct),
      ],
    );
  }
}

enum _TileState { idle, active, matched, correct, wrong }

class _PairTile extends StatelessWidget {
  const _PairTile({
    super.key,
    required this.text,
    required this.state,
    this.number,
    this.partner,
    this.onTap,
  });

  final String text;
  final _TileState state;
  final int? number;

  /// Su kuo sujungta – ekrano skaitytuvui.
  final String? partner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color border, double width, Color fill) = switch (state) {
      _TileState.idle => (scheme.outlineVariant, 1.0, scheme.surfaceContainerLow),
      _TileState.active => (scheme.primary, 3.0, scheme.primaryContainer),
      _TileState.matched => (scheme.secondary, 2.0, scheme.secondaryContainer),
      _TileState.correct => (theme.correctColor, 2.5, scheme.surfaceContainerLow),
      _TileState.wrong => (theme.incorrectColor, 2.5, scheme.surfaceContainerLow),
    };

    final Widget? marker = switch (state) {
      _TileState.correct => Icon(Icons.check_circle, color: border, size: 22),
      _TileState.wrong => Icon(Icons.cancel, color: border, size: 22),
      _TileState.matched => CircleAvatar(
          radius: 11,
          backgroundColor: scheme.secondary,
          child: Text('$number', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondary)),
        ),
      _ => null,
    };

    return Semantics(
      button: onTap != null,
      selected: state == _TileState.active,
      label: text,
      value: partner == null ? null : 'Sujungta su: $partner',
      hint: switch (state) {
        _TileState.correct => 'Teisinga pora',
        _TileState.wrong => 'Neteisinga pora',
        _ => null,
      },
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: width),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              spacing: 8,
              children: [
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
                ?marker,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Teisingi atitikmenys klaidingai sujungtoms poroms.
class _CorrectPairs extends StatelessWidget {
  const _CorrectPairs({required this.lefts, required this.correct});

  final List<String> lefts;
  final Map<String, String> correct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.correctColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text('Teisingos poros', style: theme.textTheme.titleSmall?.copyWith(color: theme.correctColor)),
          for (final l in lefts) Text('$l → ${correct[l]}', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
