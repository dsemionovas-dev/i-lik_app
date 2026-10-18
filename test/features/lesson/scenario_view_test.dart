import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';
import 'package:islik/features/lesson/presentation/widgets/scenario_view.dart';

const _safe = 'Einu į matą orientyrą azimutu';
const _risky = 'Einu „pagal jausmą“';
const _wait = 'Lieku vietoje';
const _safeOutcome = 'Saugiai išlaikai kryptį.';
const _riskyOutcome = 'Žmonės rūke dažnai suka ratu.';

const _item = ChoiceItem(
  id: 'q5',
  choiceType: ChoiceType.scenario,
  prompt: 'Miške rūkas, matomumas 20 m. Ką darai?',
  image: MediaImage(url: 'https://cdn.test/fog.webp', alt: 'Rūkas miške'),
  options: [
    QuestionOption(id: 'a', text: _safe, outcome: _safeOutcome),
    QuestionOption(id: 'b', text: _risky, outcome: _riskyOutcome),
    // Variantas be pasekmės – pasekmės blokas nerodomas.
    QuestionOption(id: 'c', text: _wait),
  ],
  correctOptionIds: ['a'],
);

Future<List<String>> _pump(WidgetTester tester, {Set<String> selected = const {}, bool locked = false}) async {
  final taps = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ScenarioView(item: _item, selectedIds: selected, locked: locked, onSelected: taps.add),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return taps;
}

/// Piktograma konkretaus kelio kortelėje.
Finder _iconOn(String text, IconData icon) => find.descendant(
  of: find.ancestor(of: find.text(text), matching: find.byType(InkWell)),
  matching: find.byIcon(icon),
);

double _opacityOf(WidgetTester tester, String text) =>
    tester.widget<Opacity>(find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first).opacity;

void main() {
  testWidgets('rodo situaciją, paveikslėlį ir kelius; pasekmės paslėptos', (tester) async {
    await _pump(tester);
    expect(find.text(_item.prompt), findsOneWidget);
    // Testuose tinklas nepasiekiamas – atsarginė piktograma.
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    for (final text in [_safe, _risky, _wait]) {
      expect(_iconOn(text, Icons.radio_button_unchecked), findsOneWidget);
    }
    expect(find.text(_safeOutcome), findsNothing);
    expect(find.text(_riskyOutcome), findsNothing);
  });

  testWidgets('paspaudus kelią praneša jo ID', (tester) async {
    final taps = await _pump(tester);
    await tester.tap(find.text(_risky));
    expect(taps, ['b']);
  });

  testWidgets('pasirinktas kelias pažymimas, bet pasekmė iki patikrinimo neatskleidžiama', (tester) async {
    await _pump(tester, selected: {'b'});
    expect(_iconOn(_risky, Icons.radio_button_checked), findsOneWidget);
    expect(find.text(_riskyOutcome), findsNothing);
    expect(find.text('Pasekmė'), findsNothing);
    expect(
      tester.getSemantics(find.ancestor(of: find.text(_risky), matching: find.byType(Semantics)).first),
      isSemantics(isSelected: true, isButton: true),
    );
  });

  testWidgets('teisingas kelias: žalia, rodoma tik jo pasekmė', (tester) async {
    await _pump(tester, selected: {'a'}, locked: true);

    expect(_iconOn(_safe, Icons.check_circle), findsOneWidget);
    expect(find.text('Pasekmė'), findsOneWidget);
    expect(find.text(_safeOutcome), findsOneWidget);
    expect(find.text('Teisingas kelias'), findsNothing);
    expect(find.text(_riskyOutcome), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(_opacityOf(tester, _risky), 0.5);
    expect(_opacityOf(tester, _safe), 1.0);
  });

  testWidgets('klaidingas kelias: raudona su pasekme, teisingas kelias parodomas, paspaudimai ignoruojami', (
    tester,
  ) async {
    final taps = await _pump(tester, selected: {'b'}, locked: true);

    expect(_iconOn(_risky, Icons.cancel), findsOneWidget);
    expect(find.text('Pasekmė'), findsOneWidget);
    expect(find.text(_riskyOutcome), findsOneWidget);

    expect(_iconOn(_safe, Icons.check_circle), findsOneWidget);
    expect(find.text('Teisingas kelias'), findsOneWidget);
    expect(find.text(_safeOutcome), findsOneWidget);

    // Nepasirinktas neteisingas be pasekmės – pritemdytas, be ženklų.
    expect(_opacityOf(tester, _wait), 0.5);
    expect(_iconOn(_wait, Icons.cancel), findsNothing);

    await tester.tap(find.text(_safe));
    await tester.tap(find.text(_wait));
    expect(taps, isEmpty);
  });

  testWidgets('pasirinkus kelią be pasekmės – tik spalva, be pasekmės bloko', (tester) async {
    await _pump(tester, selected: {'c'}, locked: true);
    expect(_iconOn(_wait, Icons.cancel), findsOneWidget);
    expect(find.text('Pasekmė'), findsNothing);
    expect(find.text('Teisingas kelias'), findsOneWidget);
  });
}
