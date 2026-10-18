import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islik/features/progress/application/progress_service.dart';
import 'package:islik/features/progress/domain/models/user_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/fakes.dart';

void main() {
  late InMemoryProgressStore store;
  late FakeProgressRemote remote;
  String? userId;
  var clock = DateTime.utc(2026, 10, 18, 9);

  ProgressService service({bool online = true, Duration timeout = const Duration(seconds: 1)}) => ProgressService(
    store: store,
    remote: online ? remote : null,
    resolveUserId: () async => userId,
    clock: () => clock,
    timeout: timeout,
  );

  Future<void> record(ProgressService s, String lessonId, double accuracy, int xp) =>
      s.recordAttempt(lessonId: lessonId, lessonVersion: 4, accuracy: accuracy, xp: xp);

  setUp(() {
    store = InMemoryProgressStore();
    remote = FakeProgressRemote();
    userId = 'user-1';
    clock = DateTime.utc(2026, 10, 18, 9);
  });

  group('vietinis įrašas', () {
    test('atnaujina progresą, įdeda į eilę ir įrašo į saugyklą be tinklo', () async {
      final s = service(online: false);
      final p = await s.recordAttempt(lessonId: 'l1', lessonVersion: 4, accuracy: 0.8, xp: 20);

      expect(p.stars, 2);
      expect(p.status, LessonProgressStatus.completed);
      expect(p.isSynced, isFalse);
      expect(s.current.outbox.single.lessonId, 'l1');
      expect(store.saved, isNotNull);
      expect(await s.sync(), isA<SyncResult>().having((r) => r.status, 'status', SyncStatus.disabled));
    });

    test('keli bandymai: XP sumuojamas, žvaigždutės – geriausios', () async {
      final s = service(online: false);
      await record(s, 'l1', 1.0, 30);
      await record(s, 'l1', 0.5, 10);

      final p = s.current.progress['l1']!;
      expect(p.xpEarned, 40);
      expect(p.stars, 3);
      expect(p.attempts, 2);
      expect(s.current.outbox, hasLength(2));
    });

    test('perkrovus programėlę eilė ir progresas išlieka', () async {
      await record(service(online: false), 'l1', 0.8, 20);

      final restarted = service(online: false);
      await restarted.load();
      expect(restarted.current.outbox, hasLength(1));
      expect(restarted.current.progress['l1']!.xpEarned, 20);
    });

    test('saugyklos klaida nenutraukia pamokos įrašo', () async {
      final s = ProgressService(store: _FailingStore(), remote: null, resolveUserId: () async => null);
      final p = await s.recordAttempt(lessonId: 'l1', lessonVersion: 1, accuracy: 1, xp: 10);
      expect(p.xpEarned, 10);
    });
  });

  group('sinchronizacija', () {
    test('išsiunčia eilę, parsisiunčia serverio progresą ir priskiria vartotoją', () async {
      final s = service();
      await record(s, 'l1', 0.8, 20);
      // Kitame įrenginyje jau buvo bandymų – serveris žino daugiau.
      remote.rows['l2'] = UserProgress.empty(
        userId: 'user-1',
        lessonId: 'l2',
        lessonVersion: 1,
        at: clock,
      ).withAttempt(accuracy: 1, xp: 30, at: clock, lessonVersion: 1);

      final result = await s.sync();

      expect(result.status, SyncStatus.synced);
      expect(result.uploaded, 1);
      expect(s.current.outbox, isEmpty);
      expect(s.current.ownerId, 'user-1');
      expect(s.current.progress.keys, unorderedEquals(['l1', 'l2']));
      expect(s.current.progress['l1']!.isSynced, isTrue);
      expect(store.saved!['outbox'], isEmpty);
    });

    test('nutrūkus ryšiui likę bandymai lieka eilėje ir vėliau išsiunčiami ta pačia tvarka', () async {
      final s = service();
      for (final (i, id) in ['a', 'b', 'c'].indexed) {
        clock = clock.add(Duration(minutes: i));
        await record(s, id, 1, 10);
      }
      remote.failWith = (a) => a.lessonId == 'b' ? const SocketException('nėra ryšio') : null;

      final first = await s.sync();
      expect(first.status, SyncStatus.offline);
      expect(first.uploaded, 1);
      expect(s.current.outbox.map((a) => a.lessonId), ['b', 'c']);
      // Vietinis progresas nepradingo.
      expect(s.current.progress.keys, containsAll(['a', 'b', 'c']));

      remote.failWith = null;
      final second = await s.sync();
      expect(second.status, SyncStatus.synced);
      expect(remote.received.map((a) => a.lessonId), ['a', 'b', 'c']);
    });

    test('pakartotinis siuntimas (pvz., po nutrūkusio atsakymo) XP nedubliuoja', () async {
      final s = service();
      await record(s, 'l1', 1, 30);
      final attempt = s.current.outbox.single;
      await remote.recordAttempt(attempt); // serveris gavo, bet klientas atsakymo nesulaukė

      await s.sync();
      expect(remote.received, hasLength(1));
      expect(s.current.progress['l1']!.xpEarned, 30);
    });

    test('serverio atmestas bandymas (22023) išmetamas, eilė nestringa', () async {
      final s = service();
      await record(s, 'bad', 1, 10);
      await record(s, 'ok', 1, 10);
      remote.failWith = (a) => a.lessonId == 'bad' ? const PostgrestException(message: 'xp', code: '22023') : null;

      final result = await s.sync();
      expect(result.status, SyncStatus.synced);
      expect(result.dropped, 1);
      expect(result.uploaded, 1);
      expect(s.current.outbox, isEmpty);
    });

    test('laikina serverio klaida (pasibaigęs JWT) stabdo, bandymai lieka', () async {
      final s = service();
      await record(s, 'l1', 1, 10);
      remote.failWith = (_) => const PostgrestException(message: 'JWT expired', code: 'PGRST301');

      final result = await s.sync();
      expect(result.status, SyncStatus.offline);
      expect(result.dropped, 0);
      expect(s.current.outbox, hasLength(1));
    });

    test('neatsakantis serveris – laiko riba, ne užstrigimas', () async {
      final s = service(timeout: const Duration(milliseconds: 20));
      await record(s, 'l1', 1, 10);
      remote.gate = Completer<void>();

      expect((await s.sync()).status, SyncStatus.offline);
      expect(s.current.outbox, hasLength(1));
    });

    test('be vartotojo (svečio nepavyko sukurti be ryšio) – nieko nesiunčia', () async {
      final s = service();
      await record(s, 'l1', 1, 10);
      userId = null;

      final result = await s.sync();
      expect(result.status, SyncStatus.notSignedIn);
      expect(result.remaining, 1);
      expect(remote.received, isEmpty);
    });

    test('vienu metu – tik viena sinchronizacija', () async {
      final s = service();
      await record(s, 'l1', 1, 10);
      remote.gate = Completer<void>();

      final a = s.sync(), b = s.sync();
      remote.gate!.complete();
      final (ra, rb) = await (a, b).wait;

      expect(identical(ra, rb), isTrue);
      expect(remote.received, hasLength(1));
    });

    test('sinchronizacijos metu užbaigta pamoka neprarandama ir neperrašoma serverio duomenimis', () async {
      final s = service();
      await record(s, 'l1', 0.6, 10);
      remote.gate = Completer<void>();

      final syncing = s.sync();
      await Future<void>.delayed(Duration.zero);
      await record(s, 'l1', 1.0, 30); // kol l1 siunčiamas
      remote.gate!.complete();
      await syncing;

      expect(s.current.outbox, hasLength(1), reason: 'naujas bandymas laukia kito karto');
      expect(s.current.progress['l1']!.xpEarned, 40, reason: 'vietinis, ne serverio (10)');

      await s.sync();
      expect(s.current.outbox, isEmpty);
      expect(s.current.progress['l1']!.xpEarned, 40);
      expect(s.current.progress['l1']!.stars, 3);
    });

    test('nepavykus parsisiųsti – išsiųsti lieka išsiųsti, vietinis progresas nepakinta', () async {
      final s = service();
      await record(s, 'l1', 1, 10);
      remote.fetchError = const SocketException('nutrūko');

      final result = await s.sync();
      expect(result.status, SyncStatus.offline);
      expect(result.uploaded, 1);
      expect(s.current.outbox, isEmpty);
      expect(s.current.progress['l1']!.xpEarned, 10);
    });
  });

  group('vartotojai', () {
    test('svečio progresas (prieš prisijungiant) priskiriamas pirmam vartotojui', () async {
      userId = null;
      final s = service();
      await record(s, 'l1', 1, 10);
      expect(s.current.ownerId, isNull);

      userId = 'guest-1';
      await s.sync();
      expect(s.current.ownerId, 'guest-1');
      expect(remote.received, hasLength(1));
    });

    test('prisijungus kitu vartotoju ankstesnio vietinė kopija išmetama', () async {
      final s = service();
      await record(s, 'l1', 1, 10);
      await s.sync();

      userId = 'user-2';
      remote
        ..rows.clear()
        ..userId = 'user-2';
      await s.sync();

      expect(s.current.ownerId, 'user-2');
      expect(s.current.progress, isEmpty);
    });

    test('clear() ištrina viską', () async {
      final s = service(online: false);
      await record(s, 'l1', 1, 10);
      await s.clear();

      expect(s.current.progress, isEmpty);
      expect(s.current.outbox, isEmpty);
      expect(store.saved!['progress'], isEmpty);
    });
  });
}

class _FailingStore extends InMemoryProgressStore {
  @override
  Future<void> write(_) async => throw const FileSystemException('diskas pilnas');
}
