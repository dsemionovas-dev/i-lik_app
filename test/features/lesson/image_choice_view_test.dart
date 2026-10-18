import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';
import 'package:islik/features/lesson/presentation/widgets/image_choice_view.dart';

const _item = ChoiceItem(
  id: 'q3',
  choiceType: ChoiceType.image,
  prompt: 'Kuriame paveikslėlyje kompasas laikomas teisingai?',
  options: [
    QuestionOption(id: 'a', image: MediaImage(url: 'https://cdn.test/a.webp', alt: 'Horizontaliai')),
    QuestionOption(id: 'b', image: MediaImage(url: 'https://cdn.test/b.webp', alt: 'Pakreiptas')),
    QuestionOption(id: 'c', image: MediaImage(url: 'https://cdn.test/c.webp', alt: 'Ant kapoto')),
  ],
  correctOptionIds: ['a'],
);

Future<List<String>> _pump(
  WidgetTester tester, {
  Set<String> selected = const {},
  bool locked = false,
}) async {
  final taps = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ImageChoiceView(
          item: _item,
          selectedIds: selected,
          locked: locked,
          onSelected: taps.add,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return taps;
}

/// Ženklelis (piktograma) konkrečioje paveikslėlio kortelėje.
Finder _badgeOn(String alt, IconData icon) => find.descendant(
      of: find.ancestor(of: find.text(alt), matching: find.byType(InkWell)),
      matching: find.byIcon(icon),
    );

void main() {
  testWidgets('rodo klausimą ir visus variantus; nepavykus įkelti – piktograma', (tester) async {
    await _pump(tester);
    expect(find.text(_item.prompt), findsOneWidget);
    for (final alt in ['Horizontaliai', 'Pakreiptas', 'Ant kapoto']) {
      expect(find.text(alt), findsOneWidget);
    }
    // Testuose tinklas nepasiekiamas – veikia errorBuilder.
    expect(find.byIcon(Icons.image_outlined), findsNWidgets(3));
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('paspaudus praneša varianto ID', (tester) async {
    final taps = await _pump(tester);
    await tester.tap(find.text('Pakreiptas'));
    expect(taps, ['b']);
  });

  testWidgets('pasirinktas variantas pažymimas', (tester) async {
    await _pump(tester, selected: {'b'});
    expect(_badgeOn('Pakreiptas', Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Pakreiptas')),
      isSemantics(label: 'Pakreiptas', isSelected: true, isButton: true),
    );
  });

  testWidgets('po neteisingo atsakymo: klaida pažymėta, teisingas parodytas, paspaudimai ignoruojami',
      (tester) async {
    final taps = await _pump(tester, selected: {'b'}, locked: true);

    expect(_badgeOn('Pakreiptas', Icons.cancel), findsOneWidget);
    expect(_badgeOn('Horizontaliai', Icons.check_circle), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Horizontaliai')),
      isSemantics(hint: 'Teisingas atsakymas', isButton: false),
    );
    // Nepasirinktas neteisingas – be ženklelio, pritemdytas.
    expect(_badgeOn('Ant kapoto', Icons.check_circle), findsNothing);
    expect(_badgeOn('Ant kapoto', Icons.cancel), findsNothing);
    final dim = tester.widget<Opacity>(
      find.ancestor(of: find.text('Ant kapoto'), matching: find.byType(Opacity)).first,
    );
    expect(dim.opacity, 0.5);

    await tester.tap(find.text('Ant kapoto'));
    expect(taps, isEmpty);
  });

  testWidgets('po teisingo atsakymo – tik vienas žalias ženklelis', (tester) async {
    await _pump(tester, selected: {'a'}, locked: true);
    expect(_badgeOn('Horizontaliai', Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });
}
