import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/app/app.dart';
import 'package:islik/core/storage/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, {bool onboarded = false}) async {
  // Kešuotas ankstesnio testo Future neužsibaigia naujo testo fake-async zonoje.
  rootBundle.clear();
  SharedPreferences.setMockInitialValues({'onboarding_completed': onboarded});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const IslikApp(),
  ));
  await tester.pumpAndSettle();
}

/// Paslenka iki elemento (mažame ekrane jis gali būti žemiau) ir paspaudžia.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Sujungia poras: paspaudžia kairįjį, tada dešinįjį elementą.
Future<void> connectPairs(WidgetTester tester, List<(String, String)> pairs) async {
  for (final (left, right) in pairs) {
    await tapVisible(tester, find.text(left));
    await tapVisible(tester, find.text(right));
  }
}

/// Paspaudžia hotspot paveikslėlyje santykinėse koordinatėse (0–1).
Future<void> tapHotspot(WidgetTester tester, double x, double y) async {
  final canvas = find.byKey(const ValueKey('hotspot-canvas'));
  await tester.ensureVisible(canvas);
  await tester.pumpAndSettle();
  final r = tester.getRect(canvas);
  await tester.tapAt(r.topLeft + Offset(r.width * x, r.height * y));
  await tester.pump();
}

void main() {
  testWidgets('naujas vartotojas nukreipiamas į onboardingą, po jo – į Pradžią', (tester) async {
    await pumpApp(tester);
    expect(find.text('Sveiki atvykę į Išlik'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('PRADĖTI'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Kita pamoka: Kompaso azimutas'), findsOneWidget);
  });

  testWidgets('skirtukai ir įdėti maršrutai', (tester) async {
    await pumpApp(tester, onboarded: true);

    await tester.tap(find.text('Gidas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('72 val. kuprinė'));
    await tester.pumpAndSettle();
    expect(find.text('Atmintinė: kuprine-72h'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Profilis'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nustatymai'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Nustatymai'), findsOneWidget);
  });

  testWidgets('pamoka atsidaro modalu virš skirtukų ir baigiasi rezultatu', (tester) async {
    await pumpApp(tester, onboarded: true);

    await tester.tap(find.text('PRADĖTI'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Kas yra azimutas?'), findsOneWidget);

    await tester.tap(find.text('SUPRATAU'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('90°'));
    await tester.pump();
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rytai – 90°'), findsOneWidget);

    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();
    // image_choice – paveikslėlių tinklelis.
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.text('Kompasas horizontaliai prie krūtinės'));
    await tester.pump();
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('toliau nuo metalo'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNothing);
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    // order_steps: pradinė tvarka visada neteisinga.
    expect(find.text('Sudėliok azimuto nustatymo žingsnius.'), findsOneWidget);
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tik tada suk žiedelį'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.text('Teisinga tvarka'), findsOneWidget);
    expect(find.text('1. Nukreipk kompaso krypties rodyklę į tikslą'), findsOneWidget);
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    // match_pairs: TIKRINTI aktyvus tik sujungus visas poras.
    expect(find.text('Sujunk kompaso dalį su jos paskirtimi.'), findsOneWidget);
    await connectPairs(tester, const [
      ('Magnetinė adata', 'Rodo magnetinę šiaurę'),
      ('Krypties rodyklė', 'Nukreipiama į tikslą'),
    ]);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'TIKRINTI')).onPressed, isNull);
    await connectPairs(tester, const [('Sukamas žiedas', 'Nustato azimutą laipsniais')]);
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Puiku – žinai'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(6));
    expect(find.text('Teisingos poros'), findsNothing);
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    // true_false: teiginys klaidingas.
    expect(find.text('Kompaso adata rodo tiksliai į geografinę šiaurę.'), findsOneWidget);
    await tapVisible(tester, find.text('Neteisinga'));
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Teisingai – adata rodo magnetinę'), findsOneWidget);
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    // hotspot: TIKRINTI aktyvus tik paspaudus paveikslėlį.
    expect(find.text('Pažymėk šiaurę kompaso skalėje.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'TIKRINTI')).onPressed, isNull);
    await tapHotspot(tester, 0.5, 0.1);
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Taip – 0° (N)'), findsOneWidget);
    expect(find.byKey(const ValueKey('hotspot-area-0')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('hotspot-marker')), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    // scenario: pasekmė atskleidžiama tik po patikrinimo.
    expect(find.text('Miške rūkas, matomumas 20 m. Tavo azimutas – 45°. Ką darai?'), findsOneWidget);
    await tapVisible(tester, find.text('Einu į matą orientyrą azimutu, tada kartoju'));
    expect(find.text('Saugiai išlaikai kryptį.'), findsNothing);
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.text('Pasekmė'), findsOneWidget);
    expect(find.text('Saugiai išlaikai kryptį.'), findsOneWidget);
    expect(find.text('Žmonės rūke dažnai suka ratu.'), findsNothing);
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    expect(find.text('Pamoka baigta!'), findsOneWidget);
    // 10 bazinis + 2 + 2 + 3 (poros) + 2 (t/n) + 3 (hotspot) + 3 (scenarijus);
    // tvarka neteisinga – be premijos, po jos tik 4 iš eilės – be combo
    expect(find.text('+25 XP'), findsOneWidget);
    expect(find.text('Tikslumas: 86 %'), findsOneWidget);

    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Kita pamoka: Kompaso azimutas'), findsOneWidget);
  });

  testWidgets('pamokos uždarymas klausia patvirtinimo', (tester) async {
    await pumpApp(tester, onboarded: true);
    await tester.tap(find.text('PRADĖTI'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Nutraukti pamoką?'), findsOneWidget);

    await tester.tap(find.text('Nutraukti'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('klaidingas scenarijaus kelias parodo abi pasekmes ir mažina tikslumą', (tester) async {
    await pumpApp(tester, onboarded: true);
    await tester.tap(find.text('PRADĖTI'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SUPRATAU'));
    await tester.pumpAndSettle();
    for (final wrong in ['0°', 'Pakreiptas kompasas']) {
      await tapVisible(tester, find.text(wrong));
      await tester.tap(find.text('TIKRINTI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TĘSTI'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('TIKRINTI')); // order_steps – pradžioje visada neteisinga
    await tester.pumpAndSettle();
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    // match_pairs: visos poros „pasuktos“ per vieną.
    await connectPairs(tester, const [
      ('Magnetinė adata', 'Nukreipiama į tikslą'),
      ('Krypties rodyklė', 'Nustato azimutą laipsniais'),
      ('Sukamas žiedas', 'Rodo magnetinę šiaurę'),
    ]);
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Adata – šiaurė'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsNWidgets(6));
    expect(find.text('Teisingos poros'), findsOneWidget);
    expect(find.text('Magnetinė adata → Rodo magnetinę šiaurę'), findsOneWidget);
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Teisinga'));
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Skirtumas nuo geografinės šiaurės'), findsOneWidget);
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    await tapHotspot(tester, 0.1, 0.5);
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Šiaurė – 0°'), findsOneWidget);
    expect(find.byKey(const ValueKey('hotspot-area-0')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('hotspot-marker')), matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Einu „pagal jausmą“, kompasą tikrinu kas valandą'));
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    expect(find.text('Neteisingai'), findsOneWidget);
    expect(find.text('Pasekmė'), findsOneWidget);
    expect(find.text('Žmonės rūke dažnai suka ratu.'), findsOneWidget);
    expect(find.text('Teisingas kelias'), findsOneWidget);
    expect(find.text('Saugiai išlaikai kryptį.'), findsOneWidget);

    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();
    expect(find.text('Pamoka baigta!'), findsOneWidget);
    // Visi atsakymai neteisingi – tik bazinis XP.
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('Tikslumas: 0 %'), findsOneWidget);
  });
}
