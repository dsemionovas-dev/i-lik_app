import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/data/lesson_repository.dart';
import 'package:islik/features/lesson/domain/models/catalog.dart';
import 'package:islik/features/lesson_tree/presentation/lesson_tree_screen.dart';

ContentCatalog _catalog(ContentSource source) => ContentCatalog(
      source: source,
      courses: const [
        Course(id: 'civil', title: 'Pilietinis saugumas', order: 4),
        Course(id: 'navigation', title: 'Navigacija', order: 3),
      ],
      units: const [CourseUnit(id: 'nav-u02', courseId: 'navigation', title: 'Kompasas', order: 2)],
      lessons: const [
        LessonSummary(id: 'b', courseId: 'navigation', unitId: 'nav-u02', title: 'Rūke', order: 4, version: 1),
        LessonSummary(
          id: 'a', courseId: 'navigation', unitId: 'nav-u02', title: 'Azimutas', order: 3, version: 4,
          estimatedMinutes: 6,
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, Future<ContentCatalog> Function() load) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [catalogProvider.overrideWith((ref) => load())],
    child: const MaterialApp(home: LessonTreeScreen()),
  ));
  await tester.pumpAndSettle();
}

double _y(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('rodo kursus, skyrius ir pamokas pagal eilę', (tester) async {
    await _pump(tester, () async => _catalog(ContentSource.remote));

    expect(_y(tester, 'Navigacija'), lessThan(_y(tester, 'Pilietinis saugumas')));
    expect(_y(tester, 'Kompasas'), lessThan(_y(tester, 'Azimutas')));
    expect(_y(tester, 'Azimutas'), lessThan(_y(tester, 'Rūke')));
    expect(find.text('6 min'), findsOneWidget);
    // Kursas be skyrių
    expect(find.text('Pamokos bus atsisiųstos prisijungus prie interneto'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });

  testWidgets('offline (kešas ar įdiegtas turinys) – rodomas pranešimas', (tester) async {
    for (final source in [ContentSource.cache, ContentSource.bundled]) {
      await _pump(tester, () async => _catalog(source));
      expect(find.text('Nėra ryšio su serveriu – rodomas išsaugotas turinys.'), findsOneWidget);
    }
  });

  testWidgets('klaida rodoma vartotojui', (tester) async {
    await _pump(tester, () async => throw Exception('nėra turinio'));
    expect(find.textContaining('Nepavyko įkelti kurso turinio'), findsOneWidget);
  });
}
