import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islik/features/feedback/application/report_service.dart';
import 'package:islik/features/feedback/data/report_repository.dart';
import 'package:islik/features/feedback/domain/content_report.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeRemote implements ReportRemoteDataSource {
  final received = <ContentReport>[];
  Object? Function(ContentReport r)? failWith;

  @override
  Future<void> send(ContentReport report) async {
    final error = failWith?.call(report);
    if (error != null) throw error;
    received.add(report);
  }
}

void main() {
  late ReportOutbox outbox;
  late _FakeRemote remote;
  var signInFails = false;
  final now = DateTime.utc(2026, 10, 18, 9);

  ReportService service({bool online = true}) => ReportService(
        outbox: outbox,
        remote: online ? remote : null,
        ensureSignedIn: () async {
          if (signInFails) throw const SocketException('nėra ryšio');
        },
        clock: () => now,
      );

  Future<ReportDelivery> submit(ReportService s, [String message = '3 klausime teisingas 90°, ne 180°']) =>
      s.submit(category: ReportCategory.contentError, message: message, lessonId: 'nav-u02-l03', itemId: 'q2');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    outbox = ReportOutbox(await SharedPreferences.getInstance());
    remote = _FakeRemote();
    signInFails = false;
  });

  test('išsiunčiama iškart su kontekstu, versija ir platforma; eilė tuščia', () async {
    expect(await submit(service()), ReportDelivery.sent);

    final r = remote.received.single;
    expect((r.category, r.lessonId, r.itemId, r.createdAt), (ReportCategory.contentError, 'nav-u02-l03', 'q2', now));
    expect(r.appVersion, isNotEmpty);
    expect(r.platform, isNotEmpty);
    expect(r.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(outbox.read(), isEmpty);
  });

  test('per trumpas aprašymas atmetamas be siuntimo; tarpai nukerpami', () async {
    await expectLater(submit(service(), '   trumpas  '), throwsA(isA<ReportValidationError>()));
    expect(outbox.read(), isEmpty);
    await submit(service(), '  Neveikia mygtukas TIKRINTI  ');
    expect(remote.received.single.message, 'Neveikia mygtukas TIKRINTI');
  });

  test('be ryšio – į eilę; vėliau išsiunčiama ta pačia tvarka', () async {
    remote.failWith = (_) => const SocketException('nėra ryšio');
    expect(await submit(service(), 'Pirmas pranešimas apie klaidą'), ReportDelivery.queued);
    expect(await submit(service(), 'Antras pranešimas apie klaidą'), ReportDelivery.queued);
    expect(outbox.read(), hasLength(2));

    remote.failWith = null;
    expect(await service().flush(), 2);
    expect(remote.received.map((r) => r.message), ['Pirmas pranešimas apie klaidą', 'Antras pranešimas apie klaidą']);
    expect(outbox.read(), isEmpty);
  });

  test('nepavykus sukurti svečio (be ryšio) – lieka eilėje', () async {
    signInFails = true;
    expect(await submit(service()), ReportDelivery.queued);
    expect(remote.received, isEmpty);
  });

  test('jau gautas (23505, pvz., atsakymas nutrūko) – laikomas išsiųstu', () async {
    remote.failWith = (_) => const PostgrestException(message: 'duplicate key', code: '23505');
    expect(await submit(service()), ReportDelivery.sent);
    expect(outbox.read(), isEmpty);
  });

  test('serverio atmestas (limitas P0429) – išmetamas, eilė neužstringa', () async {
    remote.failWith = (r) => r.message.startsWith('Šlamštas')
        ? const PostgrestException(message: 'too many reports', code: 'P0429')
        : const SocketException('nėra ryšio');
    await submit(service(), 'Šlamštas pranešimas 1');
    await submit(service(), 'Tikras pranešimas apie klaidą');
    remote.failWith = (r) => r.message.startsWith('Šlamštas') ? const PostgrestException(message: 'x', code: 'P0429') : null;

    expect(await service().flush(), 1);
    expect(remote.received.single.message, 'Tikras pranešimas apie klaidą');
    expect(outbox.read(), isEmpty);
  });

  test('laikina serverio klaida (pasibaigęs JWT) – lieka eilėje', () async {
    remote.failWith = (_) => const PostgrestException(message: 'JWT expired', code: 'PGRST301');
    expect(await submit(service()), ReportDelivery.queued);
    expect(outbox.read(), hasLength(1));
  });

  test('be Supabase – tik įrenginyje', () async {
    expect(await submit(service(online: false)), ReportDelivery.localOnly);
    expect(outbox.read(), hasLength(1));
    expect(await service(online: false).flush(), 0);
  });

  test('eilė išlieka perkrovus programėlę', () async {
    remote.failWith = (_) => const SocketException('nėra ryšio');
    await submit(service());
    final reloaded = ReportOutbox(await SharedPreferences.getInstance()).read().single;
    expect((reloaded.lessonId, reloaded.itemId, reloaded.category), ('nav-u02-l03', 'q2', ReportCategory.contentError));
  });

  test('Supabase: įrašoma į content_reports be user_id (jį nustato serveris)', () async {
    final requests = <http.Request>[];
    final source = SupabaseReportRemoteDataSource(SupabaseClient(
      'https://test.supabase.co',
      'k',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response('', 201, request: r);
      }),
    ));
    final report = ContentReport(
      id: '0b6d9c1e-8a2f-4c3d-9e5f-1a2b3c4d5e6f',
      category: ReportCategory.unsafeAdvice,
      message: 'Turniketas per žemai',
      createdAt: now,
      appVersion: '0.1.0+101',
      platform: 'android',
      guideCardId: 'kraujavimas',
    );
    await source.send(report);

    final r = requests.single;
    expect((r.method, r.url.path), ('POST', '/rest/v1/content_reports'));
    // Be „return=representation“ – klientas skaityti negali (RLS), tik įrašyti.
    expect(r.headers['Prefer'] ?? '', isNot(contains('return=representation')));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    expect(body, isNot(contains('user_id')));
    expect(body['category'], 'unsafe_advice');
    expect(body['guide_card_id'], 'kraujavimas');
    expect(body['created_at'], '2026-10-18T09:00:00.000Z');
  });
}
