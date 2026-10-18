import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';
import 'package:islik/features/lesson/presentation/widgets/match_pairs_view.dart';

const _knife = 'Peilis';
const _axe = 'Kirvis';
const _saw = 'Pjūklas';
const _cut = 'Pjaustyti virvę';
const _chop = 'Skaldyti malkas';
const _sawing = 'Pjauti storas šakas';

const _item = MatchPairsItem(
  id: 'm1',
  prompt: 'Sujunk įrankį su paskirtimi.',
  pairs: [
    MatchPair(left: _knife, right: _cut),
    MatchPair(left: _axe, right: _chop),
    MatchPair(left: _saw, right: _sawing),
  ],
);

/// Paskutinė valdiklio pranešta porų aibė.
class _Probe {
  Map<String, String> matches = const {};
  int calls = 0;
}

final _probe = _Probe();

Future<void> _pump(WidgetTester tester, {bool locked = false, int seed = 1}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MatchPairsView(
          // Tas pats raktas – būsena išlieka perpiešiant su locked: true.
          key: ValueKey('m-$seed'),
          item: _item,
          locked: locked,
          random: Random(seed),
          onMatchesChanged: (m) {
            _probe.matches = m;
            _probe.calls++;
          },
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pump();
}

Finder _iconOn(String text, IconData icon) => find.descendant(
      of: find.ancestor(of: find.text(text), matching: find.byType(InkWell)),
      matching: find.byIcon(icon),
    );

Finder _badgeOn(String text, String number) => find.descendant(
      of: find.ancestor(of: find.text(text), matching: find.byType(InkWell)),
      matching: find.widgetWithText(CircleAvatar, number),
    );

void main() {
  setUp(() {
    _probe.matches = const {};
    _probe.calls = 0;
  });

  testWidgets('rodo abu stulpelius; dešinysis niekada nesutampa su kairiuoju', (tester) async {
    for (var seed = 0; seed < 20; seed++) {
      await _pump(tester, seed: seed);
      final rightsTopToBottom = [_cut, _chop, _sawing]
        ..sort((a, b) => tester.getCenter(find.text(a)).dy.compareTo(tester.getCenter(find.text(b)).dy));
      expect(rightsTopToBottom, isNot([_cut, _chop, _sawing]), reason: 'seed $seed');
    }
    for (final t in [_knife, _axe, _saw]) {
      expect(tester.getCenter(find.text(t)).dx, lessThan(400), reason: '$t kairėje');
    }
    expect(find.text('Paspausk elementą kairėje, tada jo porą dešinėje.'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('kairė, tada dešinė – sujungiama, abu gauna tą patį numerį', (tester) async {
    await _pump(tester);
    await _tap(tester, _axe);
    expect(_probe.matches, isEmpty);
    await _tap(tester, _chop);

    expect(_probe.matches, {_axe: _chop});
    expect(_badgeOn(_axe, '2'), findsOneWidget);
    expect(_badgeOn(_chop, '2'), findsOneWidget);
  });

  testWidgets('dešinė, tada kairė – irgi sujungiama', (tester) async {
    await _pump(tester);
    await _tap(tester, _cut);
    await _tap(tester, _knife);
    expect(_probe.matches, {_knife: _cut});
    expect(_badgeOn(_cut, '1'), findsOneWidget);
  });

  testWidgets('paspaudus aktyvų elementą dar kartą – pasirinkimas atšaukiamas', (tester) async {
    await _pump(tester);
    await _tap(tester, _saw);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_saw)),
      isSemantics(label: _saw, isSelected: true, isButton: true),
    );
    await _tap(tester, _saw);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_saw)),
      isSemantics(label: _saw, isSelected: false, isButton: true),
    );
    await _tap(tester, _sawing);
    expect(_probe.matches, isEmpty, reason: 'po atšaukimo dešinė tik pažymima');
  });

  testWidgets('paspaudus sujungtą elementą pora išardoma ir galima sujungti kitaip', (tester) async {
    await _pump(tester);
    await _tap(tester, _knife);
    await _tap(tester, _chop); // klaidinga
    expect(_probe.matches, {_knife: _chop});

    await _tap(tester, _chop); // išardo, „Skaldyti malkas“ tampa aktyvus
    expect(_probe.matches, isEmpty);
    expect(find.byType(CircleAvatar), findsNothing);

    await _tap(tester, _axe);
    await _tap(tester, _knife);
    await _tap(tester, _cut);
    expect(_probe.matches, {_axe: _chop, _knife: _cut});
    expect(
      tester.getSemantics(find.bySemanticsLabel(_knife)),
      isSemantics(value: 'Sujungta su: $_cut'),
    );
  });

  testWidgets('visos poros teisingos – žalia, be „Teisingos poros“ bloko, užrakinta', (tester) async {
    await _pump(tester);
    for (final (l, r) in [(_knife, _cut), (_axe, _chop), (_saw, _sawing)]) {
      await _tap(tester, l);
      await _tap(tester, r);
    }
    await _pump(tester, locked: true);

    expect(find.byIcon(Icons.check_circle), findsNWidgets(6));
    expect(find.byIcon(Icons.cancel), findsNothing);
    expect(find.text('Teisingos poros'), findsNothing);
    expect(find.text('Paspausk elementą kairėje, tada jo porą dešinėje.'), findsNothing);

    final calls = _probe.calls;
    await _tap(tester, _knife);
    await _tap(tester, _chop);
    expect(_probe.calls, calls, reason: 'užrakinta – paspaudimai ignoruojami');
    expect(_probe.matches, {_knife: _cut, _axe: _chop, _saw: _sawing});
  });

  testWidgets('klaidingos poros raudonos, teisingos žalios, parodomi teisingi atitikmenys', (tester) async {
    await _pump(tester);
    // Peilis ir Kirvis sukeisti, Pjūklas teisingai.
    for (final (l, r) in [(_knife, _chop), (_axe, _cut), (_saw, _sawing)]) {
      await _tap(tester, l);
      await _tap(tester, r);
    }
    await _pump(tester, locked: true);

    for (final t in [_knife, _chop, _axe, _cut]) {
      expect(_iconOn(t, Icons.cancel), findsOneWidget, reason: t);
    }
    expect(_iconOn(_saw, Icons.check_circle), findsOneWidget);
    expect(_iconOn(_sawing, Icons.check_circle), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_knife)),
      isSemantics(hint: 'Neteisinga pora', isButton: false),
    );

    expect(find.text('Teisingos poros'), findsOneWidget);
    expect(find.text('$_knife → $_cut'), findsOneWidget);
    expect(find.text('$_axe → $_chop'), findsOneWidget);
    expect(find.text('$_saw → $_sawing'), findsNothing);
  });
}
