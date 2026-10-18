import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/auth/data/auth_repository.dart';
import 'package:islik/features/auth/domain/app_user.dart';
import 'package:islik/features/leagues/data/league_repository.dart';
import 'package:islik/features/leagues/domain/league.dart';
import 'package:islik/features/leagues/presentation/league_screen.dart';

import '../../helpers/fakes.dart';

final _now = DateTime.utc(2026, 10, 15, 17);

Future<void> _pump(WidgetTester tester, LeagueRepository? repo) async {
  await tester.pumpWidget(ProviderScope(
    // Be automatinio Riverpod kartojimo – tikrinam „patraukti žemyn“.
    retry: (_, _) => null,
    overrides: [
      leagueRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: const AppUser(id: 'u1'))),
    ],
    child: MaterialApp(home: LeagueScreen(now: () => _now)),
  ));
  await tester.pumpAndSettle();
}

/// Dalies sąrašo elementai gali būti žemiau ekrano – slenkam iki jų.
Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets('antraštė: lyga, numeris, likęs laikas', (tester) async {
    await _pump(tester, FakeLeagueRepository(leagueOf([30, 20, 10], tier: 3, meAt: 2)));
    expect(find.text('Žygeivis lyga'), findsOneWidget);
    expect(find.text('3 iš 10 · Liko 3 d. 4 val.'), findsOneWidget);
  });

  testWidgets('pilna grupė: zonų skirtukai tinkamose vietose, aš paryškintas', (tester) async {
    await _pump(tester, FakeLeagueRepository(leagueOf(List.generate(30, (i) => 300 - i * 10), tier: 4, meAt: 8)));

    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(find.text('Žygeivis 7')), lessThan(y(find.text('Kilimo zona'))));
    expect(y(find.text('Kilimo zona')), lessThan(y(find.text('Tu'))), reason: '8 vieta – po kilimo zonos');

    await _scrollTo(tester, find.text('Kritimo zona'));
    await _scrollTo(tester, find.text('Žygeivis 26'));
    expect(y(find.text('Žygeivis 25')), lessThan(y(find.text('Kritimo zona'))));
    expect(y(find.text('Kritimo zona')), lessThan(y(find.text('Žygeivis 26'))));
  });

  testWidgets('aš – sąraše kaip „Tu“ su XP', (tester) async {
    await _pump(tester, FakeLeagueRepository(leagueOf([30, 20, 10], meAt: 2)));
    expect(find.byKey(const ValueKey('league-me')), findsOneWidget);
    expect(find.bySemanticsLabel('2 vieta, tu, 20 XP'), findsOneWidget);
  });

  testWidgets('praėjusios savaitės rezultatas', (tester) async {
    for (final (outcome, text) in [
      (LeagueOutcome.promoted, 'Praėjusią savaitę – 1 vieta. Pakilai į „Žygeivis“ lygą!'),
      (LeagueOutcome.demoted, 'Praėjusią savaitę – 29 vieta. Nukritai į „Žygeivis“ lygą.'),
      (LeagueOutcome.stayed, 'Praėjusią savaitę – 12 vieta. Lieki „Žygeivis“ lygoje.'),
    ]) {
      final rank = switch (outcome) { LeagueOutcome.promoted => 1, LeagueOutcome.demoted => 29, _ => 12 };
      await _pump(
        tester,
        FakeLeagueRepository(leagueOf([10],
            meAt: 1,
            lastWeek: LeagueLastWeek(tier: 2, tierName: 'Stovyklautojas', finalRank: rank, outcome: outcome))),
      );
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('šią savaitę dar be XP – kvietimas užbaigti pamoką', (tester) async {
    await _pump(tester, FakeLeagueRepository(leagueOf([], joined: false)));
    expect(find.text('Užbaik pamoką, kad prisijungtum prie šios savaitės lygos.'), findsOneWidget);
    expect(find.text('Kilimo zona'), findsNothing);
  });

  testWidgets('be serverio – paaiškinimas', (tester) async {
    await _pump(tester, null);
    expect(find.text('Lygos veikia tik prisijungus prie serverio.'), findsOneWidget);
  });

  testWidgets('be ryšio – klaida, patraukus žemyn bandoma dar kartą', (tester) async {
    final repo = FakeLeagueRepository(leagueOf([10], meAt: 1))..error = const SocketException('nėra ryšio');
    await _pump(tester, repo);
    expect(find.textContaining('Nepavyko įkelti lygos'), findsOneWidget);

    repo.error = null;
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Žygeivis lyga'), findsOneWidget);
  });
}
