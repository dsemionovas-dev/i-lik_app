import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/app/app.dart';
import 'package:islik/core/storage/shared_preferences_provider.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';
import 'package:islik/features/feedback/application/report_service.dart';
import 'package:islik/features/feedback/domain/content_report.dart';
import 'package:islik/features/feedback/presentation/report_screen.dart';
import 'package:islik/features/guide/application/guide_providers.dart';
import 'package:islik/features/leagues/data/league_repository.dart';
import 'package:islik/features/lesson/data/lesson_repository.dart';
import 'package:islik/features/profile/presentation/profile_screen.dart';
import 'package:islik/features/progress/application/progress_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<void> pumpApp(WidgetTester tester, {bool onboarded = false, List<Override> overrides = const []}) async {
  // Kešuotas ankstesnio testo Future neužsibaigia naujo testo fake-async zonoje.
  rootBundle.clear();
  SharedPreferences.setMockInitialValues({'onboarding_completed': onboarded});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        lessonCacheProvider.overrideWithValue(InMemoryLessonCache()),
        progressStoreProvider.overrideWithValue(InMemoryProgressStore()),
        guideCacheProvider.overrideWithValue(InMemoryGuideCache()),
        ...overrides,
      ],
      child: const IslikApp(),
    ),
  );
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

/// Pranešimo formoje paslenka iki „Siųsti“ ir paspaudžia.
Future<void> tapSend(WidgetTester tester) async {
  final form = find.descendant(of: find.byType(ReportScreen), matching: find.byType(Scrollable)).first;
  // scrollUntilVisible sustoja, kai mygtukas sukurtas (gali būti dar už ekrano) –
  // ensureVisible jį tikrai parodo.
  await tester.scrollUntilVisible(find.text('Siųsti'), 200, scrollable: form);
  await tester.ensureVisible(find.text('Siųsti'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Siųsti'));
  await tester.pump();
}

/// Profilio sąraše paslenka iki [finder] (ilgas sąrašas – apačia dar nesukurta).
Future<void> revealInProfile(WidgetTester tester, Finder finder) async {
  final list = find.descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable)).first;
  // Į viršų – be „patraukti žemyn“ (jis paleistų sinchronizaciją).
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 150, scrollable: list);
  await tester.pumpAndSettle();
}

/// Profilio statistikos plytelės reikšmė pagal pavadinimą.
String statValue(WidgetTester tester, String label) => tester
    .widget<Text>(
      find
          .descendant(
            of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
            matching: find.byType(Text),
          )
          .first,
    )
    .data!;

/// Pereina visą pamoką neteisingais atsakymais (0 %, 10 XP) iki rezultatų ekrano.
Future<void> finishLessonAllWrong(WidgetTester tester) async {
  await tester.tap(find.text('PRADĖTI'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('SUPRATAU'));
  await tester.pumpAndSettle();
  Future<void> checkAndContinue() async {
    await tester.tap(find.text('TIKRINTI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();
  }

  await tapVisible(tester, find.text('0°'));
  await checkAndContinue();
  await tapVisible(tester, find.text('Pakreiptas kompasas'));
  await checkAndContinue();
  await checkAndContinue(); // order_steps
  await connectPairs(tester, const [
    ('Magnetinė adata', 'Nukreipiama į tikslą'),
    ('Krypties rodyklė', 'Nustato azimutą laipsniais'),
    ('Sukamas žiedas', 'Rodo magnetinę šiaurę'),
  ]);
  await checkAndContinue();
  await tapVisible(tester, find.text('Teisinga'));
  await checkAndContinue();
  await tapHotspot(tester, 0.1, 0.5);
  await checkAndContinue();
  await tapVisible(tester, find.text('Einu „pagal jausmą“, kompasą tikrinu kas valandą'));
  await checkAndContinue();
  expect(find.text('Pamoka baigta!'), findsOneWidget);
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

  testWidgets('gidas pasiekiamas be registracijos, kiti skirtukai – tik po onboardingo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Atidaryti gidą be registracijos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Gidas'), findsOneWidget);

    await tester.tap(find.text('Sirenos ir įspėjimai'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dėmesio visiems'), findsOneWidget);

    await tester.tap(find.text('Pradžia'));
    await tester.pumpAndSettle();
    expect(find.text('Sveiki atvykę į Išlik'), findsOneWidget);
  });

  testWidgets('nustatymuose – pranešimas apie klaidą (be serverio – įrenginyje)', (tester) async {
    await pumpApp(tester, onboarded: true);
    await tester.tap(find.text('Profilis'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nustatymai'));
    await tester.pumpAndSettle();
    expect(find.text('Versija'), findsOneWidget);
    await tester.tap(find.text('Pranešti apie klaidą'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report-context')), findsNothing);
    expect(
      tester.widget<RadioGroup<ReportCategory>>(find.byType(RadioGroup<ReportCategory>)).groupValue,
      ReportCategory.fromKey('app_bug'),
    );
    await tester.enterText(find.byKey(const ValueKey('report-message')), 'Neveikia');
    await tapSend(tester);
    expect(find.text('Aprašykite plačiau – bent 10 simbolių.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('report-message')), 'Neveikia garsas pamokose.');
    await tapSend(tester);
    await tester.pumpAndSettle();
    expect(find.text('Ačiū! Pranešimas išsaugotas įrenginyje.'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Nustatymai'), findsOneWidget);
  });

  testWidgets('gido atmintinėje – pranešti galima ir be registracijos', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Atidaryti gidą be registracijos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('72 val. kuprinė'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pranešti apie klaidą'));
    await tester.pumpAndSettle();
    expect(find.text('Gido atmintinė kuprine-72h'), findsOneWidget);
    expect(find.text('Sveiki atvykę į Išlik'), findsNothing, reason: 'ne nukreipta į onboardingą');
  });

  testWidgets('skirtukai ir įdėti maršrutai', (tester) async {
    await pumpApp(tester, onboarded: true);

    await tester.tap(find.text('Gidas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('72 val. kuprinė'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '72 val. kuprinė'), findsOneWidget);
    expect(find.text('Turite: 0 iš 12'), findsOneWidget);
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
    // Be Supabase – tik šiame įrenginyje.
    expect(find.text('Progresas išsaugotas šiame įrenginyje.'), findsOneWidget);
    // Pirmoji pamoka; skyriuje „Kompasas“ ji vienintelė.
    expect(find.text('Nauji ženkleliai!'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-badge-pirmoji-pamoka')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-badge-kompaso-meistras')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-badge-be-klaidu')), findsNothing, reason: '86 %, ne 100 %');

    await tester.tap(find.text('TĘSTI'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Kita pamoka: Kompaso azimutas'), findsOneWidget);

    // Progresas matomas profilyje ir kelyje (86 % → 2 žvaigždutės).
    await tester.tap(find.text('Profilis'));
    await tester.pumpAndSettle();
    expect(statValue(tester, 'XP'), '25');
    expect(statValue(tester, 'Baigtos pamokos'), '1');
    expect(statValue(tester, 'Serija (d.)'), '1');

    // Ženkleliai: gautas – su data, negautas – su progresu.
    await revealInProfile(tester, find.text('Ženkleliai · 2 iš 11'));
    await tester.tap(find.byKey(const ValueKey('badge-pirmoji-pamoka')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gautas 20'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20)); // uždaryti
    await tester.pumpAndSettle();
    await revealInProfile(tester, find.byKey(const ValueKey('badge-smalsuolis')));
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('badge-smalsuolis')));
    await tester.pumpAndSettle();
    expect(find.text('Baik 5 pamokas.'), findsOneWidget);
    expect(find.text('Progresas: 1 / 5'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kelias'));
    await tester.pumpAndSettle();
    // Navigacijos kursas – trečias, žemiau ekrano.
    await tester.scrollUntilVisible(find.text('★★☆'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('★★☆'), findsOneWidget);
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

  group('su Supabase (fiktyvus serveris)', () {
    late FakeAuthRepository auth;
    late FakeProgressRemote remote;
    late FakeLeagueRepository leagues;
    late FakeReportRemote reports;

    List<Override> online() => [
      authRepositoryProvider.overrideWithValue(auth),
      progressRemoteDataSourceProvider.overrideWithValue(remote),
      leagueRepositoryProvider.overrideWithValue(leagues),
      reportRemoteDataSourceProvider.overrideWithValue(reports),
    ];

    setUp(() {
      auth = FakeAuthRepository(user: const AppUser(id: 'guest-1', isAnonymous: true));
      remote = FakeProgressRemote(userId: 'guest-1');
      leagues = FakeLeagueRepository(leagueOf([30, 20, 10], tier: 3, meAt: 2));
      reports = FakeReportRemote();
    });

    testWidgets('pamokoje – pranešimas apie klaidą su pamokos ir užduoties kontekstu', (tester) async {
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('PRADĖTI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SUPRATAU'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pranešti apie klaidą'));
      await tester.pumpAndSettle();
      expect(find.text('Pamoka nav-u02-l03, užduotis q2'), findsOneWidget);
      // Iš pamokos – numatytoji kategorija „Klaida turinyje“.
      expect(
        tester.widget<RadioGroup<ReportCategory>>(find.byType(RadioGroup<ReportCategory>)).groupValue,
        ReportCategory.fromKey('content_error'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('report-message')),
        'Rytai yra 90°, bet paaiškinime parašyta kitaip.',
      );
      await tapSend(tester);
      await tester.pumpAndSettle();

      expect(find.text('Ačiū! Pranešimas išsiųstas.'), findsOneWidget);
      final r = reports.received.single;
      expect((r.lessonId, r.itemId, r.category), ('nav-u02-l03', 'q2', ReportCategory.contentError));
      // Grįžtama į tą pačią užduotį.
      expect(find.text('Koks azimutas rodo tiesiai į rytus?'), findsOneWidget);
    });

    testWidgets('be ryšio pranešimas išsaugomas ir išsiunčiamas grįžus į programėlę', (tester) async {
      reports.error = const SocketException('nėra ryšio');
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nustatymai'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pranešti apie klaidą'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('report-category-unsafe_advice')));
      await tester.pumpAndSettle();
      expect(find.text('Ačiū – tokie pranešimai peržiūrimi pirmiausia.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('report-message')),
        'Hipotermijos atmintinėje trūksta įspėjimo.',
      );
      await tapSend(tester);
      await tester.pumpAndSettle();
      expect(find.text('Ačiū! Pranešimas išsaugotas ir bus išsiųstas, kai atsiras ryšys.'), findsOneWidget);
      expect(reports.received, isEmpty);

      reports.error = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reports.received.single.category, ReportCategory.unsafeAdvice);
    });

    testWidgets('susietai paskyrai be slaptažodžio pasiūloma jį nustatyti', (tester) async {
      auth.setUser(const AppUser(id: 'guest-1', email: 'jonas@pastas.lt', needsPassword: true));
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      await revealInProfile(tester, find.text('Paskyra'));
      expect(find.textContaining('Nustatykite slaptažodį'), findsOneWidget);

      Future<void> submit(String password, String confirmation) async {
        await tapVisible(tester, find.text('Nustatyti slaptažodį'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('new-password-field')), password);
        await tester.enterText(find.byKey(const ValueKey('confirm-password-field')), confirmation);
        await tester.tap(find.text('Išsaugoti'));
        await tester.pumpAndSettle();
      }

      await submit('Kompasas42', 'Kompasas24');
      expect(find.text('Slaptažodžiai nesutampa.'), findsOneWidget);
      expect(auth.calls, isNot(contains('setPassword')));

      await submit('Kompasas42', 'Kompasas42');
      expect(auth.calls, contains('setPassword'));
      expect(find.textContaining('Slaptažodis nustatytas'), findsOneWidget);
      expect(find.text('Nustatyti slaptažodį'), findsNothing);
      expect(find.text('Keisti slaptažodį'), findsOneWidget);
    });

    testWidgets('el. paštą patvirtinus naršyklėje – grįžus pasiūlomas slaptažodis', (tester) async {
      auth.setUser(const AppUser(id: 'guest-1', isAnonymous: true, pendingEmail: 'jonas@pastas.lt'));
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      await revealInProfile(tester, find.text('Paskyra'));
      expect(find.textContaining('Laukiama patvirtinimo: jonas@pastas.lt'), findsOneWidget);

      auth.afterRefresh = const AppUser(id: 'guest-1', email: 'jonas@pastas.lt', needsPassword: true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(auth.calls, contains('refreshUser'));
      expect(find.textContaining('Laukiama patvirtinimo'), findsNothing);
      expect(find.text('Nustatyti slaptažodį'), findsOneWidget);
    });

    testWidgets('pamiršus slaptažodį – kodas iš laiško ir naujas slaptažodis', (tester) async {
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      await revealInProfile(tester, find.text('Jau turiu paskyrą'));
      await tapVisible(tester, find.text('Jau turiu paskyrą'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('email-field')), 'jonas@pastas.lt');
      await tester.tap(find.text('Pamiršau slaptažodį?'));
      await tester.pumpAndSettle();

      // El. paštas perkeltas iš prisijungimo lango.
      expect(find.widgetWithText(AppBar, 'Slaptažodžio atstatymas'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'jonas@pastas.lt'), findsOneWidget);
      await tester.tap(find.text('Siųsti kodą'));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('reset:jonas@pastas.lt'));

      Future<void> submit(String code) async {
        await tester.enterText(find.byKey(const ValueKey('reset-code-field')), code);
        await tester.enterText(find.byKey(const ValueKey('reset-password-field')), 'Kompasas42');
        await tester.enterText(find.byKey(const ValueKey('reset-confirm-field')), 'Kompasas42');
        await tapVisible(tester, find.text('Keisti slaptažodį'));
        await tester.pumpAndSettle();
      }

      await submit('000000');
      expect(find.text('Kodas neteisingas arba nebegalioja. Paprašykite naujo.'), findsOneWidget);
      expect(auth.currentUser!.isAnonymous, isTrue);

      await submit('123456');
      expect(find.text('Slaptažodis pakeistas – esate prisijungę.'), findsOneWidget);
      expect(auth.calls, containsAllInOrder(['verify:123456', 'setPassword']));

      await tester.tap(find.text('Grįžti'));
      await tester.pumpAndSettle();
      await revealInProfile(tester, find.byKey(const ValueKey('account-email')));
      expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
      expect(find.text('jonas@pastas.lt'), findsWidgets);
    });

    testWidgets('atidarius atstatymo nuorodą iš laiško – naujo slaptažodžio ekranas', (tester) async {
      auth.setUser(const AppUser(id: 'user-1', email: 'jonas@pastas.lt'));
      await pumpApp(tester, onboarded: true, overrides: online());

      auth.emitPasswordRecovery();
      await tester.pumpAndSettle();
      expect(find.text('Sukurkite naują slaptažodį.'), findsOneWidget);
      expect(find.byKey(const ValueKey('reset-code-field')), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('reset-password-field')), 'Kompasas42');
      await tester.enterText(find.byKey(const ValueKey('reset-confirm-field')), 'Kompasas42');
      await tester.tap(find.text('Išsaugoti'));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('setPassword'));
      expect(find.text('Slaptažodis pakeistas – esate prisijungę.'), findsOneWidget);

      await tester.tap(find.text('Grįžti'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('profilio vardas ir avataras', (tester) async {
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('profile-name'))).data, startsWith('Žygeivis '));

      await tester.tap(find.byTooltip('Redaguoti profilį'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('display-name-field')), 'Jo');
      await tester.tap(find.text('Išsaugoti'));
      await tester.pumpAndSettle();
      expect(find.text('Vardas per trumpas – bent 3 simboliai.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('display-name-field')), 'Miško Lapė');
      await tester.tap(find.byKey(const ValueKey('avatar-owl')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Išsaugoti'));
      await tester.pumpAndSettle();

      expect(find.text('Profilis išsaugotas.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('profile-name'))).data, 'Miško Lapė');
      expect(tester.widget<Text>(find.byKey(const ValueKey('profile-avatar'))).data, '🦉');
    });

    testWidgets('profilyje – lygos kortelė, paspaudus – lentelė', (tester) async {
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      expect(find.text('Žygeivis lyga'), findsOneWidget);
      expect(find.text('2 vieta · 20 XP šią savaitę'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('league-card')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Lyga'), findsOneWidget);
      expect(find.byKey(const ValueKey('league-me')), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget, reason: 'profilio skirtuko viduje');
    });

    testWidgets('išsiuntus pamoką lyga atnaujinama', (tester) async {
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      final before = leagues.calls;

      leagues.standing = leagueOf([30, 20, 10], tier: 3, meAt: 1);
      await tester.tap(find.text('Pradžia'));
      await tester.pumpAndSettle();
      await finishLessonAllWrong(tester);
      await tester.tap(find.text('TĘSTI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();

      expect(leagues.calls, greaterThan(before));
      expect(find.text('1 vieta · 30 XP šią savaitę'), findsOneWidget);
    });

    testWidgets('užbaigta pamoka iškart išsiunčiama į serverį', (tester) async {
      await pumpApp(tester, onboarded: true, overrides: online());
      await finishLessonAllWrong(tester);

      expect(find.text('Progresas išsaugotas.'), findsOneWidget);
      final attempt = remote.received.single;
      expect((attempt.lessonId, attempt.lessonVersion, attempt.xp, attempt.accuracy), ('nav-u02-l03', 4, 10, 0.0));
      expect(remote.rows['nav-u02-l03']!.xpEarned, 10);
    });

    testWidgets('be ryšio progresas kaupiamas ir išsiunčiamas grįžus į programėlę', (tester) async {
      remote.failWith = (_) => const SocketException('nėra ryšio');
      await pumpApp(tester, onboarded: true, overrides: online());
      await finishLessonAllWrong(tester);

      expect(find.text('Progresas išsaugotas įrenginyje ir bus išsiųstas, kai atsiras ryšys.'), findsOneWidget);
      await tester.tap(find.text('TĘSTI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      expect(statValue(tester, 'XP'), '10', reason: 'vietinis progresas matomas be ryšio');
      expect(find.text('Laukia išsiuntimo: 1 (nėra ryšio)'), findsOneWidget);
      expect(remote.received, isEmpty);

      // Atsirado ryšys; vartotojas grįžta į programėlę.
      remote.failWith = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(remote.received, hasLength(1));
      expect(find.textContaining('Laukia išsiuntimo'), findsNothing);
      expect(statValue(tester, 'XP'), '10');
    });

    testWidgets('profilyje svečias gali susieti el. paštą', (tester) async {
      await pumpApp(tester, onboarded: true, overrides: online());
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      await revealInProfile(tester, find.text('Susieti el. paštą'));
      expect(find.text('Svečio režimas'), findsOneWidget);

      await tester.tap(find.text('Susieti el. paštą'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('email-field')), 'jonas@pastas.lt');
      await tester.tap(find.text('Tęsti'));
      await tester.pumpAndSettle();

      expect(auth.calls, contains('link:jonas@pastas.lt'));
      expect(find.textContaining('Patvirtinkite el. paštą'), findsOneWidget);
    });

    testWidgets('atsijungimas įspėja apie neišsiųstus bandymus ir išvalo vietinį progresą', (tester) async {
      auth.setUser(const AppUser(id: 'user-1', email: 'jonas@pastas.lt'));
      remote
        ..userId = 'user-1'
        ..failWith = (_) => const SocketException('nėra ryšio');
      await pumpApp(tester, onboarded: true, overrides: online());
      await finishLessonAllWrong(tester);
      await tester.tap(find.text('TĘSTI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profilis'));
      await tester.pumpAndSettle();
      await revealInProfile(tester, find.text('Atsijungti'));
      expect(find.byKey(const ValueKey('account-email')), findsOneWidget);

      await tapVisible(tester, find.text('Atsijungti'));
      await tester.pumpAndSettle();
      expect(find.text('Dar neišsiųsta bandymų: 1. Atsijungus jie bus prarasti.'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Atsijungti'));
      await tester.pumpAndSettle();

      expect(auth.currentUser, isNull);
      await revealInProfile(tester, find.text('XP'));
      expect(statValue(tester, 'XP'), '0');
      await revealInProfile(tester, find.text('Neprisijungta.'));
      expect(find.text('Neprisijungta.'), findsOneWidget);
    });
  });
}
