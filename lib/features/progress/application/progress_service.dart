import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:uuid/uuid.dart';

import '../data/progress_remote_data_source.dart';
import '../data/progress_store.dart';
import '../domain/models/lesson_attempt.dart';
import '../domain/models/user_progress.dart';

/// Vietinė kalendorinė diena `YYYY-MM-DD` (serijai skaičiuoti).
String dayKey(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

enum SyncStatus {
  /// Serveris nesukonfigūruotas – progresas tik įrenginyje.
  disabled,

  /// Nepavyko gauti vartotojo (pvz., svečio sukūrimas be ryšio).
  notSignedIn,

  /// Dalis ar visi bandymai liko eilėje (nėra ryšio).
  offline,

  /// Eilė tuščia, progresas atnaujintas iš serverio.
  synced,
}

class SyncResult {
  const SyncResult(this.status, {this.uploaded = 0, this.dropped = 0, this.remaining = 0});

  final SyncStatus status;
  final int uploaded;

  /// Serverio atmesti (netinkami) bandymai – kartoti beprasmiška.
  final int dropped;
  final int remaining;

  @override
  String toString() => 'SyncResult($status, ↑$uploaded, ✗$dropped, ⧗$remaining)';
}

/// Offline-first progresas:
/// 1. [recordAttempt] iškart atnaujina vietinį progresą ir įdeda bandymą į eilę.
/// 2. [sync] siunčia eilę eilės tvarka; nutrūkus ryšiui likusieji lieka kitam kartui.
/// 3. Ištuštinus eilę – serverio progresas (jau sujungtas iš visų įrenginių)
///    tampa vietine kopija.
class ProgressService {
  ProgressService({
    required ProgressStore store,
    required ProgressRemoteDataSource? remote,
    required Future<String?> Function() resolveUserId,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
    this.timeout = const Duration(seconds: 10),
  }) : _store = store,
       _remote = remote,
       _resolveUserId = resolveUserId,
       _uuid = uuid,
       _clock = clock ?? DateTime.now;

  final ProgressStore _store;
  final ProgressRemoteDataSource? _remote;
  final Future<String?> Function() _resolveUserId;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final Duration timeout;

  ProgressSnapshot? _snapshot;
  Future<SyncResult>? _syncInFlight;
  Future<void> _writes = Future.value();

  bool get syncEnabled => _remote != null;

  /// Dabartinė kopija (po [load] – visada naujausia).
  ProgressSnapshot get current => _snapshot ?? ProgressSnapshot();

  Future<ProgressSnapshot> load() async {
    if (_snapshot != null) return _snapshot!;
    ProgressSnapshot? stored;
    try {
      stored = await _store.read();
    } catch (e) {
      _log('Nepavyko perskaityti vietinio progreso', e);
    }
    return _snapshot ??= stored ?? ProgressSnapshot();
  }

  /// Įrašo užbaigtą pamoką vietoje ir įdeda į siuntimo eilę. Tinklo nereikia.
  Future<UserProgress> recordAttempt({
    required String lessonId,
    required int lessonVersion,
    required double accuracy,
    required int xp,
  }) async {
    final snapshot = await load();
    final now = _clock();
    final attempt = LessonAttempt(
      id: _uuid.v4(),
      lessonId: lessonId,
      lessonVersion: lessonVersion,
      accuracy: accuracy.clamp(0, 1).toDouble(),
      xp: xp,
      completedAt: now,
    );
    final current =
        snapshot.progress[lessonId] ??
        UserProgress.empty(userId: snapshot.ownerId ?? '', lessonId: lessonId, lessonVersion: lessonVersion, at: now);
    final updated = current.withAttempt(accuracy: attempt.accuracy, xp: xp, at: now, lessonVersion: lessonVersion);

    snapshot.progress[lessonId] = updated;
    snapshot.outbox.add(attempt);
    snapshot.activityDays.add(dayKey(now));
    await _persist();
    return updated;
  }

  /// Vienu metu vyksta tik viena sinchronizacija; kiti kvietėjai gauna jos rezultatą.
  Future<SyncResult> sync() => _syncInFlight ??= _sync().whenComplete(() => _syncInFlight = null);

  Future<SyncResult> _sync() async {
    final snapshot = await load();
    final remote = _remote;
    if (remote == null) return SyncResult(SyncStatus.disabled, remaining: snapshot.outbox.length);

    String? userId;
    try {
      userId = await _resolveUserId();
    } catch (e) {
      _log('Nepavyko gauti vartotojo', e);
    }
    if (userId == null) return SyncResult(SyncStatus.notSignedIn, remaining: snapshot.outbox.length);
    await _adoptOwner(userId);

    var uploaded = 0, dropped = 0;
    for (final attempt in [...snapshot.outbox]) {
      try {
        await remote.recordAttempt(attempt).timeout(timeout);
        uploaded++;
      } on PostgrestException catch (e) {
        if (!_isPermanent(e)) {
          _log('Serveris laikinai nepasiekiamas', e);
          return _offline(uploaded, dropped);
        }
        // Netinkami duomenys – kartojant niekas nepasikeis, nestabdom eilės.
        _log('Serveris atmetė bandymą ${attempt.id}', e);
        dropped++;
      } catch (e) {
        _log('Nėra ryšio – bandymai lieka eilėje', e);
        return _offline(uploaded, dropped);
      }
      snapshot.outbox.removeWhere((a) => a.id == attempt.id);
      await _persist();
    }

    try {
      final rows = await remote.fetchProgress().timeout(timeout);
      // Kol siuntėme, galėjo atsirasti naujų bandymų – jų vietinio progreso neperrašom.
      final pendingLessons = {for (final a in snapshot.outbox) a.lessonId};
      snapshot.progress.removeWhere((id, _) => !pendingLessons.contains(id));
      for (final row in rows) {
        if (!pendingLessons.contains(row.lessonId)) snapshot.progress[row.lessonId] = row;
      }
      await _persist();
    } catch (e) {
      _log('Nepavyko parsisiųsti progreso', e);
      return _offline(uploaded, dropped);
    }
    return SyncResult(SyncStatus.synced, uploaded: uploaded, dropped: dropped, remaining: snapshot.outbox.length);
  }

  /// Ištrina vietinį progresą (pvz., atsijungus).
  Future<void> clear() async {
    final snapshot = await load();
    snapshot
      ..ownerId = null
      ..progress.clear()
      ..outbox.clear()
      ..activityDays.clear();
    await _persist();
  }

  /// Pirmą kartą prisijungus – vietiniai (svečio) duomenys priskiriami vartotojui.
  /// Prisijungus kitu vartotoju – ankstesnio vartotojo kopija išmetama.
  Future<void> _adoptOwner(String userId) async {
    final snapshot = await load();
    if (snapshot.ownerId == userId) return;
    if (snapshot.ownerId != null) {
      _log('Pasikeitė vartotojas – vietinis progresas išvalomas', snapshot.ownerId!);
      snapshot
        ..progress.clear()
        ..outbox.clear()
        ..activityDays.clear();
    }
    snapshot.ownerId = userId;
    await _persist();
  }

  SyncResult _offline(int uploaded, int dropped) =>
      SyncResult(SyncStatus.offline, uploaded: uploaded, dropped: dropped, remaining: _snapshot!.outbox.length);

  /// Postgres klaidų klasės: 22 – netinkami duomenys, 23 – apribojimai (pvz., nėra pamokos),
  /// P0 – funkcijos `raise`. Kitos (JWT, 5xx, PGRST) – laikinos.
  static bool _isPermanent(PostgrestException e) => RegExp(r'^(22|23|P0)').hasMatch(e.code ?? '');

  /// Įrašai eina vienas po kito – du lygiagretūs įrašai nesusidurtų ties laikinu failu.
  Future<void> _persist() {
    final snapshot = _snapshot!;
    return _writes = _writes.then((_) => _store.write(snapshot)).catchError((Object e) {
      _log('Nepavyko įrašyti vietinio progreso', e);
    });
  }

  void _log(String message, Object error) => developer.log('$message: $error', name: 'islik.progress');
}
