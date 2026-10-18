import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/core/utils/json.dart';
import 'package:islik/features/lesson/domain/models/lesson.dart';
import 'package:islik/features/lesson/domain/models/lesson_result.dart';

void main() {
  late Json json;
  late Lesson lesson;

  setUp(() {
    json = jsonDecode(File('assets/lessons/nav-u02-l03.json').readAsStringSync()) as Json;
    lesson = Lesson.fromJson(json);
  });

  test('PRD pavyzdys nuskaitomas į tinkamus tipus', () {
    expect(lesson.id, 'nav-u02-l03');
    expect(lesson.rewards.baseXp, 10);
    expect(lesson.review?.status, ReviewStatus.approved);
    expect(lesson.items.map((i) => i.runtimeType), [
      InfoCardItem,
      ChoiceItem,
      ChoiceItem,
      OrderStepsItem,
      MatchPairsItem,
      TrueFalseItem,
      HotspotItem,
      ChoiceItem,
    ]);
    final scenario = lesson.items.last as ChoiceItem;
    expect(scenario.choiceType, ChoiceType.scenario);
    expect(scenario.options.first.outcome, 'Saugiai išlaikai kryptį.');
  });

  test('toJson → fromJson išlaiko visus duomenis', () {
    final roundTrip = Lesson.fromJson(jsonDecode(jsonEncode(lesson.toJson())) as Json);
    expect(jsonEncode(roundTrip.toJson()), jsonEncode(lesson.toJson()));
  });

  test('atsakymų tikrinimas', () {
    final q2 = lesson.items[1] as ChoiceItem;
    expect(q2.isCorrect({'b'}), isTrue);
    expect(q2.isCorrect({'a'}), isFalse);
    expect(q2.isCorrect({'a', 'b'}), isFalse);

    final q4 = lesson.items[3] as OrderStepsItem;
    expect(q4.isCorrect(['s1', 's2', 's3']), isTrue);
    expect(q4.isCorrect(['s2', 's1', 's3']), isFalse);
  });

  test('nežinomas tipas nelaužo pamokos ir praleidžiamas', () {
    final withFuture = {
      ...json,
      'items': [
        ...json['items'] as List<dynamic>,
        {'id': 'q9', 'type': 'ar_scan', 'foo': 1},
      ],
    };
    final parsed = Lesson.fromJson(withFuture);
    expect(parsed.items.last, isA<UnsupportedItem>());
    expect(parsed.items.last.toJson()['foo'], 1);
    expect(parsed.playableItems, hasLength(8));
  });

  test('XP skaičiavimas pagal PRD taisykles', () {
    final graded = lesson.items.where((i) => i.isGraded).toList();
    // Užduočių XP: q2 2, q3 2, q4 3, q5 3, q6 2, q7 3, q8 3 = 18
    // 10 bazinis + 18 + combo 3 × 2 (5-as, 6-as, 7-as iš eilės) + 5 be klaidų
    expect(LessonResult.calculateXp(lesson: lesson, answers: List.filled(7, true), gradedItems: graded), 39);
    // Klaida 2-oje: 10 + 2 + 3 + 3 + 2 + 3 + 3 = 26, combo tik 7-ai (5-a iš eilės) +2
    expect(
      LessonResult.calculateXp(
        lesson: lesson,
        answers: [true, false, true, true, true, true, true],
        gradedItems: graded,
      ),
      28,
    );
  });

  test('true_false nuskaitomas ir tikrinamas', () {
    final q6 = lesson.items[5] as TrueFalseItem;
    expect(q6.correctAnswer, isFalse);
    expect(q6.isCorrect(false), isTrue);
    expect(q6.isCorrect(true), isFalse);
  });

  test('hotspot: spindulys pločio dalimis, sritis lieka apskritimu bet kokiose proporcijose', () {
    final q7 = lesson.items[6] as HotspotItem;
    expect(q7.aspectRatio, 1.0);
    expect(q7.isCorrect(0.5, 0.1), isTrue);
    expect(q7.isCorrect(0.5, 0.9), isFalse);

    const wide = HotspotItem(
      id: 'w',
      prompt: '',
      image: MediaImage(url: 'u', alt: ''),
      targetAreas: [HotspotArea(x: 0.5, y: 0.5, r: 0.1)],
      aspectRatio: 2,
    );
    // Aukštis = pusė pločio: 0.15 aukščio = 0.075 pločio < 0.1 → viduje.
    expect(wide.isCorrect(0.5, 0.65), isTrue);
    // 0.15 pločio > 0.1 → už ribos.
    expect(wide.isCorrect(0.65, 0.5), isFalse);

    // Be aspectRatio JSON'e – kvadratas.
    final noRatio = HotspotItem.fromJson({...q7.toJson()}..remove('aspectRatio'));
    expect(noRatio.aspectRatio, 1.0);
  });

  test('porų tikrinimas reikalauja visų teisingų porų', () {
    final q5 = lesson.items[4] as MatchPairsItem;
    final correct = {for (final p in q5.pairs) p.left: p.right};
    expect(q5.isCorrect(correct), isTrue);
    expect(q5.isCorrect({...correct}..remove('Sukamas žiedas')), isFalse);
    expect(
      q5.isCorrect({
        ...correct,
        'Magnetinė adata': 'Nukreipiama į tikslą',
        'Krypties rodyklė': 'Rodo magnetinę šiaurę',
      }),
      isFalse,
    );
  });
}
