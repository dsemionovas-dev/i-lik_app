import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:islik/core/storage/shared_preferences_provider.dart';
import 'package:islik/features/guide/application/guide_providers.dart';
import 'package:islik/features/guide/data/guide_repository.dart';
import 'package:islik/features/guide/presentation/guide_card_screen.dart';
import 'package:islik/features/guide/presentation/guide_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import 'guide_test.dart' show bundledGuideJson;

late List<Uri> opened;
late FakeGuideRemote remote;

Future<void> _pump(WidgetTester tester, {String location = '/guide', Map<String, Object> prefs = const {}}) async {
  rootBundle.clear();
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(
      path: '/guide',
      builder: (_, _) => const GuideScreen(),
      routes: [GoRoute(path: ':id', builder: (_, s) => GuideCardScreen(cardId: s.pathParameters['id']!))],
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      guideRepositoryProvider.overrideWithValue(
        GuideRepository(cache: InMemoryGuideCache(), remote: remote, bundle: rootBundle),
      ),
      urlOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    opened = [];
    remote = FakeGuideRemote();
  });

  testWidgets('sąrašas: 112 kortelė viršuje, offline žyma, visos atmintinės', (tester) async {
    await _pump(tester);
    expect(find.text('Skubi pagalba – 112'), findsWidgets);
    expect(find.text('Visos atmintinės veikia be interneto'), findsOneWidget);
    expect(find.text('72 val. kuprinė'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('call-112')));
    expect(opened, [Uri(scheme: 'tel', path: '112')]);
  });

  testWidgets('paieška be lietuviškų raidžių ir tuščias rezultatas', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const ValueKey('guide-search')), 'sirenos');
    await tester.pumpAndSettle();
    expect(find.text('Sirenos ir įspėjimai'), findsOneWidget);
    expect(find.text('72 val. kuprinė'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('guide-search')), 'zvaigzde');
    await tester.pumpAndSettle();
    expect(find.text('Kryptis be kompaso'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('guide-search')), 'kosmosas');
    await tester.pumpAndSettle();
    expect(find.text('Nieko nerasta. Pabandykite kitą žodį.'), findsOneWidget);

    await tester.tap(find.byTooltip('Išvalyti'));
    await tester.pumpAndSettle();
    expect(find.text('72 val. kuprinė'), findsOneWidget);
  });

  testWidgets('kategorija filtruoja', (tester) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pirmoji pagalba'));
    await tester.pumpAndSettle();
    expect(find.text('Gaivinimas suaugusiajam'), findsOneWidget);
    expect(find.text('72 val. kuprinė'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Visos'));
    await tester.pumpAndSettle();
    expect(find.text('72 val. kuprinė'), findsOneWidget);
  });

  testWidgets('atmintinė: žingsniai, įspėjimas, 112, šaltiniai, pastaba', (tester) async {
    await _pump(tester, location: '/guide/gaivinimas');
    expect(find.widgetWithText(AppBar, 'Gaivinimas suaugusiajam'), findsOneWidget);
    expect(find.textContaining('Darykite 30 paspaudimų'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('card-call-112')));
    expect(opened.single, Uri(scheme: 'tel', path: '112'));

    await tester.scrollUntilVisible(find.byIcon(Icons.warning_amber_rounded), 200);
    expect(find.textContaining('nepertraukiamai spauskite krūtinę'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Šaltiniai'), 200);
    expect(find.text('Atmintinė nepakeičia praktinių mokymų. Pavojuje – skambinkite 112.'), findsOneWidget);
    await tester.tap(find.text('https://www.erc.edu'));
    expect(opened.last, Uri.parse('https://www.erc.edu'));
  });

  testWidgets('kuprinės sąrašas: žymės išsaugomos įrenginyje', (tester) async {
    await _pump(tester, location: '/guide/kuprine-72h');
    expect(find.text('Turite: 0 iš 12'), findsOneWidget);
    Future<void> tapItem(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    await tapItem('Grynieji pinigai');
    await tapItem('Švilpukas');
    await tester.scrollUntilVisible(find.text('Turite: 2 iš 12'), -200);
    expect(find.text('Turite: 2 iš 12'), findsOneWidget);
    await tapItem('Švilpukas');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('checklist-progress')), -200);
    expect(find.text('Turite: 1 iš 12'), findsOneWidget);

    final saved = (await SharedPreferences.getInstance()).getStringList('guide_checklist_kuprine-72h');
    expect(saved, ['Grynieji pinigai']);

    // „Perkrovus programėlę“
    await _pump(tester, location: '/guide/kuprine-72h', prefs: {'guide_checklist_kuprine-72h': saved!});
    expect(find.text('Turite: 1 iš 12'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Grynieji pinigai')).value, isTrue);
  });

  testWidgets('nežinoma atmintinė', (tester) async {
    await _pump(tester, location: '/guide/nera-tokios');
    expect(find.text('Atmintinė nerasta.'), findsOneWidget);
  });

  testWidgets('naujesnė versija iš serverio pakeičia turinį fone', (tester) async {
    final json = bundledGuideJson();
    final cards = [
      ...json['cards'] as List,
      {
        'id': 'nauja', 'categoryId': 'crisis', 'title': 'Nauja atmintinė', 'summary': 'Iš serverio',
        'blocks': [{'kind': 'text', 'text': 'Tekstas'}], 'sources': [{'title': 'X'}],
      },
    ];
    remote.guide = {...json, 'version': 2, 'cards': cards};
    await _pump(tester);
    // Pirmas – vertikalus sąrašas (kategorijų žymos slenka horizontaliai).
    await tester.scrollUntilVisible(find.text('Nauja atmintinė'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Nauja atmintinė'), findsOneWidget);
    expect(jsonEncode(remote.calls), '1');
  });
}
