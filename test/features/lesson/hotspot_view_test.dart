import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';
import 'package:islik/features/lesson/presentation/widgets/hotspot_view.dart';

const _north = HotspotArea(x: 0.5, y: 0.1, r: 0.1);

HotspotItem _item({double aspectRatio = 1}) => HotspotItem(
      id: 'h1',
      prompt: 'Pažymėk šiaurę.',
      image: const MediaImage(url: 'https://cdn.test/dial.webp', alt: 'Kompaso skalė'),
      targetAreas: const [_north],
      aspectRatio: aspectRatio,
    );

final _canvas = find.byKey(const ValueKey('hotspot-canvas'));
final _area = find.byKey(const ValueKey('hotspot-area-0'));
final _marker = find.byKey(const ValueKey('hotspot-marker'));

Future<List<Offset>> _pump(
  WidgetTester tester, {
  Offset? tap,
  bool locked = false,
  double aspectRatio = 1,
}) async {
  final taps = <Offset>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        // Siauras rėmas, kad visas paveikslėlis tilptų į testo ekraną.
        child: SizedBox(
          width: 300,
          child: HotspotView(
            item: _item(aspectRatio: aspectRatio),
            tap: tap,
            locked: locked,
            onTap: taps.add,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return taps;
}

Offset _at(WidgetTester tester, double x, double y) {
  final r = tester.getRect(_canvas);
  return r.topLeft + Offset(r.width * x, r.height * y);
}

void main() {
  testWidgets('rodo klausimą ir paveikslėlį; sričių ir žymeklio dar nėra', (tester) async {
    await _pump(tester);
    expect(find.text('Pažymėk šiaurę.'), findsOneWidget);
    expect(find.text('Paspausk paveikslėlyje.'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(_area, findsNothing);
    expect(_marker, findsNothing);
    expect(tester.getSize(_canvas), const Size(300, 300));
  });

  testWidgets('paspaudimas praneša santykines koordinates', (tester) async {
    final taps = await _pump(tester);
    await tester.tapAt(_at(tester, 0.5, 0.1));
    await tester.tapAt(_at(tester, 0.25, 0.75));
    expect(taps, hasLength(2));
    expect(taps[0].dx, closeTo(0.5, 0.01));
    expect(taps[0].dy, closeTo(0.1, 0.01));
    expect(taps[1].dx, closeTo(0.25, 0.01));
    expect(taps[1].dy, closeTo(0.75, 0.01));
  });

  testWidgets('kol netikrinta – žymeklis paspaustoje vietoje, teisinga sritis paslėpta', (tester) async {
    await _pump(tester, tap: const Offset(0.2, 0.6));
    final c = tester.getCenter(_marker);
    final expected = _at(tester, 0.2, 0.6);
    expect(c.dx, closeTo(expected.dx, 0.5));
    expect(c.dy, closeTo(expected.dy, 0.5));
    expect(_area, findsNothing);
    expect(find.text('Gali paspausti kitoje vietoje, kad pakeistum.'), findsOneWidget);
    expect(find.descendant(of: _marker, matching: find.byType(Icon)), findsNothing);
  });

  testWidgets('pataikius – sritis parodoma, žymeklis su ✓', (tester) async {
    await _pump(tester, tap: const Offset(0.52, 0.12), locked: true);
    final area = tester.getRect(_area);
    final center = _at(tester, 0.5, 0.1);
    expect(area.center.dx, closeTo(center.dx, 0.5));
    expect(area.center.dy, closeTo(center.dy, 0.5));
    expect(area.width, closeTo(60, 0.5)); // 2 × 0.1 × 300
    expect(find.descendant(of: _marker, matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(find.text('Žalia sritis – teisinga vieta.'), findsOneWidget);
  });

  testWidgets('nepataikius – žymeklis su ✗, sritis parodoma, paspaudimai ignoruojami', (tester) async {
    final taps = await _pump(tester, tap: const Offset(0.5, 0.9), locked: true);
    expect(_area, findsOneWidget);
    expect(find.descendant(of: _marker, matching: find.byIcon(Icons.close)), findsOneWidget);

    await tester.tapAt(_at(tester, 0.5, 0.1));
    expect(taps, isEmpty);
  });

  testWidgets('plačiame paveikslėlyje sritis lieka apskritimu', (tester) async {
    await _pump(tester, tap: const Offset(0.5, 0.1), locked: true, aspectRatio: 2);
    expect(tester.getSize(_canvas), const Size(300, 150));
    final area = tester.getRect(_area);
    expect(area.width, closeTo(area.height, 0.01));
    expect(area.width, closeTo(60, 0.5));
  });
}
