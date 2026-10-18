import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';
import 'package:islik/features/lesson/presentation/widgets/true_false_view.dart';

const _item = TrueFalseItem(
  id: 'tf1',
  prompt: 'Kompaso adata rodo tiksliai į geografinę šiaurę.',
  correctAnswer: false,
);

Future<List<bool>> _pump(WidgetTester tester, {bool? answer, bool locked = false}) async {
  final taps = <bool>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TrueFalseView(item: _item, answer: answer, locked: locked, onAnswer: taps.add),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return taps;
}

Finder _iconOn(String label, IconData icon) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      matching: find.byIcon(icon),
    );

double _opacityOf(WidgetTester tester, String label) => tester
    .widget<Opacity>(find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first)
    .opacity;

void main() {
  testWidgets('rodo teiginį ir du mygtukus be įvertinimo', (tester) async {
    await _pump(tester);
    expect(find.text(_item.prompt), findsOneWidget);
    expect(find.text('Teisinga'), findsOneWidget);
    expect(find.text('Neteisinga'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('mygtukai praneša true / false', (tester) async {
    final taps = await _pump(tester);
    await tester.tap(find.text('Teisinga'));
    await tester.tap(find.text('Neteisinga'));
    expect(taps, [true, false]);
  });

  testWidgets('pasirinktas mygtukas pažymimas', (tester) async {
    await _pump(tester, answer: true);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Teisinga')),
      isSemantics(label: 'Teisinga', isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Neteisinga')),
      isSemantics(label: 'Neteisinga', isSelected: false, isButton: true),
    );
  });

  testWidgets('teisingas atsakymas – žalias ✓, kitas pritemdytas', (tester) async {
    await _pump(tester, answer: false, locked: true);
    expect(_iconOn('Neteisinga', Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(_opacityOf(tester, 'Teisinga'), 0.5);
  });

  testWidgets('klaidingas atsakymas – raudonas ✗, teisingas parodomas, užrakinta', (tester) async {
    final taps = await _pump(tester, answer: true, locked: true);
    expect(_iconOn('Teisinga', Icons.cancel), findsOneWidget);
    expect(_iconOn('Neteisinga', Icons.check_circle), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Neteisinga')),
      isSemantics(hint: 'Teisingas atsakymas', isButton: false),
    );

    await tester.tap(find.text('Neteisinga'));
    expect(taps, isEmpty);
  });
}
