import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/lesson/data/bundled_content_source.dart';
import 'package:islik/features/lesson/domain/models/catalog.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('įdiegtas katalogas atitinka įdiegtas pamokas', () async {
    final source = BundledContentSource();
    final catalog = await source.loadCatalog();

    expect(catalog.source, ContentSource.bundled);
    expect(catalog.courses.map((c) => c.title), ['Išgyvenimas gamtoje', 'Įranga', 'Navigacija', 'Pilietinis saugumas']);
    // Kiekviena kataloge nurodyta pamoka yra assets ir jos versija sutampa.
    for (final summary in catalog.lessons) {
      final json = await source.loadLesson(summary.id);
      expect(json, isNotNull, reason: summary.id);
      expect(Lesson.fromJson(json!).version, summary.version, reason: summary.id);
    }
  });

  test('nesamos pamokos atveju – null, ne klaida', () async {
    expect(await BundledContentSource().loadLesson('nera-tokios'), isNull);
  });
}
