import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islik/features/progress/data/progress_remote_data_source.dart';
import 'package:islik/features/progress/domain/models/lesson_attempt.dart';
import 'package:islik/features/progress/domain/models/user_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;

  SupabaseProgressRemoteDataSource source() => SupabaseProgressRemoteDataSource(
    SupabaseClient(
      'https://test.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
    ),
  );

  http.Response json(http.Request request, Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
    request: request,
  );

  setUp(() => requests = []);

  final attempt = LessonAttempt(
    id: '0b6d9c1e-8a2f-4c3d-9e5f-1a2b3c4d5e6f',
    lessonId: 'nav-u02-l03',
    lessonVersion: 4,
    accuracy: 0.857,
    xp: 25,
    completedAt: DateTime.utc(2026, 10, 18, 9, 30),
  );

  test('bandymas siunčiamas per RPC record_lesson_attempt', () async {
    respond = (r) => json(r, {'lesson_id': 'nav-u02-l03'});
    await source().recordAttempt(attempt);

    final r = requests.single;
    expect(r.method, 'POST');
    expect(r.url.path, '/rest/v1/rpc/record_lesson_attempt');
    expect(jsonDecode(r.body), {
      'p_attempt_id': '0b6d9c1e-8a2f-4c3d-9e5f-1a2b3c4d5e6f',
      'p_lesson_id': 'nav-u02-l03',
      'p_lesson_version': 4,
      'p_accuracy': 0.857,
      'p_xp': 25,
      'p_completed_at': '2026-10-18T09:30:00.000Z',
    });
  });

  test('serverio atmetimo kodas perduodamas (pagal jį servisas sprendžia, ar kartoti)', () async {
    respond = (r) => json(r, {'code': '22023', 'message': 'xp out of range: 9999'}, 400);
    expect(source().recordAttempt(attempt), throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '22023')));
  });

  test('progresas: snake_case eilutės → UserProgress', () async {
    respond = (r) => json(r, [
      {
        'user_id': 'u1',
        'lesson_id': 'nav-u02-l03',
        'lesson_version': 4,
        'status': 'completed',
        'stars': 2,
        'best_accuracy': 0.857,
        'xp_earned': 47,
        'attempts': 2,
        'completed_at': '2026-10-18T09:30:00+00:00',
        'updated_at': '2026-10-18T10:00:00+00:00',
      },
    ]);
    final rows = await source().fetchProgress();

    expect(requests.single.url.path, '/rest/v1/user_lesson_progress');
    final p = rows.single;
    expect(p.status, LessonProgressStatus.completed);
    expect((p.stars, p.xpEarned, p.attempts, p.bestAccuracy, p.isSynced), (2, 47, 2, 0.857, true));
    expect(p.completedAt, DateTime.utc(2026, 10, 18, 9, 30));
  });
}
