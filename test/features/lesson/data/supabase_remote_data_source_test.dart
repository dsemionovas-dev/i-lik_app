import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islik/features/lesson/data/lesson_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tikras SupabaseClient su fiktyviu HTTP – tikrina tikras PostgREST užklausas.
void main() {
  late List<http.Request> requests;
  late Map<String, Object?> responses;

  SupabaseLessonRemoteDataSource source() {
    final client = SupabaseClient(
      'https://test.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = responses[request.url.pathSegments.last];
        const headers = {'content-type': 'application/json; charset=utf-8'};
        if (body == null) {
          return http.Response('{"message":"klaida"}', 500, headers: headers, request: request);
        }
        return http.Response(jsonEncode(body), 200, headers: headers, request: request);
      }),
    );
    return SupabaseLessonRemoteDataSource(client);
  }

  setUp(() {
    requests = [];
    responses = {};
  });

  test('katalogas: trys užklausos, snake_case → modeliai, rikiavimas', () async {
    responses = {
      'courses': [
        {'id': 'navigation', 'title': 'Navigacija', 'description': null, 'sort_order': 3},
      ],
      'units': [
        {'id': 'nav-u02', 'course_id': 'navigation', 'title': 'Kompasas', 'description': 'Azimutas', 'sort_order': 2},
      ],
      'lessons': [
        {
          'id': 'nav-u02-l04', 'course_id': 'navigation', 'unit_id': 'nav-u02', 'title': 'Rūke',
          'sort_order': 4, 'version': 1, 'estimated_minutes': 7,
        },
        {
          'id': 'nav-u02-l03', 'course_id': 'navigation', 'unit_id': 'nav-u02', 'title': 'Azimutas',
          'sort_order': 3, 'version': 4, 'estimated_minutes': null,
        },
      ],
    };

    final catalog = await source().fetchCatalog();

    expect(requests.map((r) => r.url.path), unorderedEquals([
      '/rest/v1/courses',
      '/rest/v1/units',
      '/rest/v1/lessons',
    ]));
    // Visos trys rikiuojamos didėjančiai (postgrest numatytasis – mažėjančiai).
    for (final r in requests) {
      expect(r.url.queryParameters['order'], 'sort_order.asc.nullslast', reason: r.url.path);
    }
    final lessonsReq = requests.firstWhere((r) => r.url.path.endsWith('lessons'));
    expect(lessonsReq.url.queryParameters['select'],
        'id,course_id,unit_id,title,sort_order,version,estimated_minutes');
    expect(lessonsReq.headers['apikey'], 'publishable-key');
    // Turinys (jsonb) kataloge nesiunčiamas.
    expect(lessonsReq.url.queryParameters['select'], isNot(contains('content')));

    expect(catalog.courses.single.title, 'Navigacija');
    expect(catalog.unitsOf('navigation').single.description, 'Azimutas');
    expect(catalog.lessons.map((l) => l.id), ['nav-u02-l03', 'nav-u02-l04']);
    expect(catalog.lesson('nav-u02-l03')!.estimatedMinutes, 5);
    expect(catalog.lesson('nav-u02-l04')!.estimatedMinutes, 7);
  });

  test('pamokos turinys pagal ID', () async {
    responses = {
      'lessons': [
        {'content': {'id': 'nav-u02-l03', 'version': 4}},
      ],
    };
    final json = await source().fetchLessonContent('nav-u02-l03');

    expect(json, {'id': 'nav-u02-l03', 'version': 4});
    final q = requests.single.url.queryParameters;
    expect(q['select'], 'content');
    expect(q['id'], 'eq.nav-u02-l03');
  });

  test('nerasta (arba nepatvirtinta – RLS) pamoka grąžina null', () async {
    responses = {'lessons': <Object>[]};
    expect(await source().fetchLessonContent('juodrastis'), isNull);
  });

  test('serverio klaida perduodama repozitorijai kaip išimtis', () async {
    expect(source().fetchCatalog(), throwsA(isA<PostgrestException>()));
  });
}
