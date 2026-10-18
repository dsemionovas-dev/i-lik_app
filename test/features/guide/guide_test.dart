import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/core/utils/json.dart';
import 'package:islik/features/guide/domain/guide.dart';

Json bundledGuideJson() => jsonDecode(File('assets/guide/guide.json').readAsStringSync()) as Json;

void main() {
  late GuideBook book;
  setUp(() => book = GuideBook.fromJson(bundledGuideJson()));

  group('įdiegtas turinys (PRD: šaltiniai, be žaidimo mechanikos)', () {
    test('kiekviena kortelė turi kategoriją, santrauką, turinį ir šaltinį', () {
      expect(book.cards, hasLength(greaterThanOrEqualTo(10)));
      final ids = <String>{};
      for (final card in book.cards) {
        expect(ids.add(card.id), isTrue, reason: 'dubliuotas ID ${card.id}');
        expect(RegExp(r'^[a-z0-9-]+$').hasMatch(card.id), isTrue, reason: card.id);
        expect(card.summary, isNotEmpty, reason: card.id);
        expect(card.blocks, isNotEmpty, reason: card.id);
        expect(card.sources, isNotEmpty, reason: '${card.id} be šaltinio');
        for (final block in card.blocks) {
          final hasContent = block.kind == GuideBlockKind.text || block.kind == GuideBlockKind.warning
              ? (block.text ?? '').isNotEmpty
              : block.items.isNotEmpty;
          expect(hasContent, isTrue, reason: '${card.id}: tuščias ${block.kind.name}');
        }
      }
    });

    test('kiekviena kategorija turi korteles', () {
      for (final c in book.categories) {
        expect(book.search(categoryId: c.id), isNotEmpty, reason: c.id);
      }
    });

    test('skubios pagalbos kortelės siūlo skambinti 112', () {
      for (final id in ['skubi-pagalba-112', 'kraujavimas', 'gaivinimas']) {
        expect(book.card(id)!.emergencyCall, isTrue, reason: id);
      }
    });
  });

  group('paieška', () {
    test('be diakritikų ir didžiųjų raidžių', () {
      expect(foldForSearch('Ąžuolas ČIUOŽIA ūkyje'), 'azuolas ciuozia ukyje');
      expect(book.search(query: 'kraujavimas').map((c) => c.id), contains('kraujavimas'));
      expect(book.search(query: 'SIRENOS').map((c) => c.id), contains('sirenos'));
      expect(book.search(query: 'siaure').map((c) => c.id), contains('kryptis-be-kompaso'));
    });

    test('ieško ir pagal raktažodžius bei turinį; visi žodžiai turi būti', () {
      expect(book.search(query: 'aed').map((c) => c.id), ['gaivinimas']);
      expect(book.search(query: 'turniketas').map((c) => c.id), ['kraujavimas']);
      expect(book.search(query: 'virinti tabletes').map((c) => c.id), ['vanduo']);
      expect(book.search(query: 'virinti zvaigzde'), isEmpty);
    });

    test('kategorija ir paieška kartu', () {
      expect(book.search(query: '112', categoryId: 'wild').map((c) => c.id), ['pasiklydus']);
      expect(book.search(categoryId: 'first-aid').map((c) => c.categoryId), everyElement('first-aid'));
    });
  });

  group('validacija', () {
    test('nežinoma kategorija – klaida', () {
      final json = bundledGuideJson();
      (json['cards'] as List).add({'id': 'x', 'categoryId': 'nera', 'title': 'X', 'summary': 'x', 'blocks': []});
      expect(() => GuideBook.fromJson(json), throwsFormatException);
    });

    test('be kortelių – klaida', () {
      expect(() => GuideBook.fromJson({...bundledGuideJson(), 'cards': <Object>[]}), throwsFormatException);
    });

    test('nežinomas bloko tipas rodomas kaip tekstas (senesnė programėlė nelūžta)', () {
      expect(GuideBlockKind.fromKey('video'), GuideBlockKind.text);
    });
  });
}
