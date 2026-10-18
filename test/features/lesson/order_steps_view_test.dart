import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';
import 'package:islik/features/lesson/presentation/widgets/order_steps_view.dart';

const _item = OrderStepsItem(
  id: 'q4',
  prompt: 'Sudėliok',
  steps: [
    OrderStep(id: 's1', text: 'Pirmas'),
    OrderStep(id: 's2', text: 'Antras'),
    OrderStep(id: 's3', text: 'Trečias'),
  ],
  correctOrder: ['s1', 's2', 's3'],
);

/// Paskutinė valdiklio pranešta tvarka.
class _Probe {
  List<String> order = const [];
}

Future<_Probe> _pumpView(
  WidgetTester tester, {
  OrderStepsItem item = _item,
  bool locked = false,
  int seed = 1,
}) async {
  final probe = _Probe();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: OrderStepsView(
          key: UniqueKey(),
          item: item,
          locked: locked,
          random: Random(seed),
          onOrderChanged: (ids) => probe.order = ids,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return probe;
}

void main() {
  testWidgets('pradinė tvarka niekada nebūna teisinga ir iškart pranešama', (tester) async {
    for (var seed = 0; seed < 30; seed++) {
      final probe = await _pumpView(tester, seed: seed);
      expect(probe.order, hasLength(3));
      expect(_item.isCorrect(probe.order), isFalse, reason: 'seed $seed');
    }
  });

  testWidgets('nutempus pirmą žingsnį į apačią jis tampa paskutinis', (tester) async {
    final probe = await _pumpView(tester);
    final initial = probe.order;
    final first = _item.steps.firstWhere((s) => s.id == initial.first);

    final handle = find.descendant(
      of: find.ancestor(of: find.text(first.text), matching: find.byType(Card)),
      matching: find.byIcon(Icons.drag_handle),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(probe.order, [...initial.skip(1), first.id]);
  });

  testWidgets('užrakinus rankenėlių nebelieka', (tester) async {
    await _pumpView(tester, locked: true);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.text('Pirmas'), findsOneWidget);
  });

  testWidgets('po neteisingo atsakymo pozicijos pažymimos ir parodoma teisinga tvarka', (tester) async {
    final probe = await _pumpView(tester, locked: true);
    final inPlace = [
      for (final (i, id) in probe.order.indexed) _item.correctOrder[i] == id,
    ];

    expect(find.byIcon(Icons.check_circle), findsNWidgets(inPlace.where((x) => x).length));
    expect(find.byIcon(Icons.cancel), findsNWidgets(inPlace.where((x) => !x).length));
    expect(find.byIcon(Icons.cancel), findsWidgets);

    expect(find.text('Teisinga tvarka'), findsOneWidget);
    expect(find.text('1. Pirmas'), findsOneWidget);
    expect(find.text('2. Antras'), findsOneWidget);
    expect(find.text('3. Trečias'), findsOneWidget);
  });

  testWidgets('teisingai sudėliojus teisingos tvarkos blokas nerodomas', (tester) async {
    // Vieno žingsnio nėra ką maišyti – tvarka visada teisinga.
    const single = OrderStepsItem(
      id: 'q1',
      prompt: 'Vienas',
      steps: [OrderStep(id: 's1', text: 'Vienintelis')],
      correctOrder: ['s1'],
    );
    await _pumpView(tester, item: single, locked: true);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.text('Teisinga tvarka'), findsNothing);
  });

  testWidgets('kol netikrinta – jokių teisingumo ženklų', (tester) async {
    await _pumpView(tester);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.text('Teisinga tvarka'), findsNothing);
  });
}
