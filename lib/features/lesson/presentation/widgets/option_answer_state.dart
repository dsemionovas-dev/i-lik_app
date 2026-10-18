import '../../domain/models/lesson.dart';

/// Pasirinkimo varianto būsena prieš ir po „TIKRINTI“.
enum OptionAnswerState {
  idle,
  selected,

  /// Pasirinkta ir teisinga.
  correct,

  /// Teisinga, bet vartotojas jos nepasirinko.
  missedCorrect,

  /// Pasirinkta, bet neteisinga.
  wrong,

  /// Nepasirinkta ir neteisinga – po patikrinimo nebesvarbi.
  dimmed;

  static OptionAnswerState of(
    ChoiceItem item,
    String optionId, {
    required Set<String> selectedIds,
    required bool locked,
  }) {
    return resolve(
      selected: selectedIds.contains(optionId),
      isCorrectOption: item.correctOptionIds.contains(optionId),
      locked: locked,
    );
  }

  /// Bendra taisyklė bet kuriam variantui (taip pat „Teisinga“ / „Neteisinga“).
  static OptionAnswerState resolve({
    required bool selected,
    required bool isCorrectOption,
    required bool locked,
  }) {
    if (!locked) return selected ? OptionAnswerState.selected : OptionAnswerState.idle;
    if (isCorrectOption) {
      return selected ? OptionAnswerState.correct : OptionAnswerState.missedCorrect;
    }
    return selected ? OptionAnswerState.wrong : OptionAnswerState.dimmed;
  }

  bool get isSelected => this == selected || this == correct || this == wrong;

  String get semanticsHint => switch (this) {
        correct => 'Teisingas atsakymas, pasirinkta',
        missedCorrect => 'Teisingas atsakymas',
        wrong => 'Neteisingas atsakymas',
        _ => '',
      };
}
