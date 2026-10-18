import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:uuid/uuid.dart';

import '../../../core/config/env.dart';
import '../../../core/storage/shared_preferences_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/clock.dart';
import '../../auth/data/auth_repository.dart';
import '../data/report_repository.dart';
import '../domain/content_report.dart';

enum ReportDelivery {
  /// Gauta serveryje.
  sent,

  /// Įrašyta įrenginyje, bus išsiųsta atsiradus ryšiui.
  queued,

  /// Serveris nesukonfigūruotas (kūrimo režimas).
  localOnly,
}

/// Pranešimas niekada neprarandamas: pirmiausia – į eilę, tada bandoma išsiųsti.
class ReportService {
  ReportService({
    required ReportOutbox outbox,
    required ReportRemoteDataSource? remote,
    required Future<void> Function() ensureSignedIn,
    DateTime Function()? clock,
    Uuid uuid = const Uuid(),
    this.timeout = const Duration(seconds: 10),
  }) : _outbox = outbox,
       _remote = remote,
       _ensureSignedIn = ensureSignedIn,
       _clock = clock ?? DateTime.now,
       _uuid = uuid;

  final ReportOutbox _outbox;
  final ReportRemoteDataSource? _remote;
  final Future<void> Function() _ensureSignedIn;
  final DateTime Function() _clock;
  final Uuid _uuid;
  final Duration timeout;
  Future<int>? _flushing;

  int get pending => _outbox.read().length;

  Future<ReportDelivery> submit({
    required ReportCategory category,
    required String message,
    String? lessonId,
    String? itemId,
    String? guideCardId,
  }) async {
    final error = ContentReport.validateMessage(message);
    if (error != null) throw ReportValidationError(error);
    final report = ContentReport(
      id: _uuid.v4(),
      category: category,
      message: message.trim(),
      createdAt: _clock(),
      appVersion: Env.appVersion,
      platform: defaultTargetPlatform.name,
      lessonId: lessonId,
      itemId: itemId,
      guideCardId: guideCardId,
    );
    await _outbox.write([..._outbox.read(), report]);
    if (_remote == null) return ReportDelivery.localOnly;
    await flush();
    return _outbox.read().any((r) => r.id == report.id) ? ReportDelivery.queued : ReportDelivery.sent;
  }

  /// Išsiunčia eilę; grąžina išsiųstų skaičių. Vienu metu – vienas siuntimas.
  Future<int> flush() => _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<int> _flush() async {
    final remote = _remote;
    if (remote == null || _outbox.read().isEmpty) return 0;
    try {
      await _ensureSignedIn();
    } on Object catch (e) {
      _log('Nepavyko prisijungti', e);
      return 0;
    }
    var sent = 0;
    for (final report in _outbox.read()) {
      try {
        await remote.send(report).timeout(timeout);
        sent++;
      } on PostgrestException catch (e) {
        // 23505 – jau gautas (pakartotinis siuntimas). Kiti 22/23/P0 – serveris atmetė:
        // kartoti beprasmiška. Likusios (JWT, 5xx) – laikinos.
        final code = e.code ?? '';
        if (code == '23505') {
          sent++;
        } else if (!RegExp(r'^(22|23|P0)').hasMatch(code)) {
          _log('Laikina klaida – pranešimai lieka eilėje', e);
          return sent;
        } else {
          _log('Serveris atmetė pranešimą ${report.id}', e);
        }
      } on Object catch (e) {
        _log('Nėra ryšio – pranešimai lieka eilėje', e);
        return sent;
      }
      await _outbox.write(_outbox.read().where((r) => r.id != report.id).toList());
    }
    return sent;
  }

  void _log(String message, Object error) => developer.log('$message: $error', name: 'islik.feedback');
}

class ReportValidationError implements Exception {
  const ReportValidationError(this.message);
  final String message;

  @override
  String toString() => message;
}

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseReportRemoteDataSource(client);
});

final reportServiceProvider = Provider<ReportService>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return ReportService(
    outbox: ReportOutbox(ref.watch(sharedPreferencesProvider)),
    remote: ref.watch(reportRemoteDataSourceProvider),
    // Pranešti galima ir prieš onboardingą (pvz., iš gido) – sukuriamas svečias.
    ensureSignedIn: () => auth.ensureSignedIn(),
    clock: ref.watch(clockProvider),
  );
});
