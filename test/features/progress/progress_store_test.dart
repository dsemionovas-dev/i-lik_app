import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/progress/data/progress_store.dart';
import 'package:islik/features/progress/domain/models/lesson_attempt.dart';
import 'package:islik/features/progress/domain/models/user_progress.dart';

void main() {
  late Directory dir;
  late FileProgressStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('islik_progress_');
    store = FileProgressStore(file: () async => File('${dir.path}/progress.json'));
  });

  tearDown(() => dir.delete(recursive: true));

  test('tuščia – null', () async {
    expect(await store.read(), isNull);
  });

  test('įrašyta būsena perskaitoma su eile ir isSynced žyme', () async {
    final at = DateTime.utc(2026, 10, 18, 9, 30);
    final progress = UserProgress.empty(userId: 'u1', lessonId: 'l1', lessonVersion: 4, at: at)
        .withAttempt(accuracy: 0.8, xp: 20, at: at, lessonVersion: 4);
    await store.write(ProgressSnapshot(
      ownerId: 'u1',
      progress: {'l1': progress},
      outbox: [
        LessonAttempt(id: 'a1', lessonId: 'l1', lessonVersion: 4, accuracy: 0.8, xp: 20, completedAt: at),
      ],
    ));

    final read = (await store.read())!;
    expect(read.ownerId, 'u1');
    final p = read.progress['l1']!;
    expect((p.stars, p.xpEarned, p.bestAccuracy, p.isSynced), (2, 20, 0.8, false));
    expect(p.completedAt, at);
    final a = read.outbox.single;
    expect((a.id, a.accuracy, a.completedAt), ('a1', 0.8, at));
  });

  test('sugadintas ar senos schemos failas – null, ne klaida', () async {
    final file = File('${dir.path}/progress.json');
    await file.writeAsString('{nebaigtas');
    expect(await store.read(), isNull);
    await file.writeAsString('{"progress": [{"lesson_id": 5}]}');
    expect(await store.read(), isNull);
  });
}
