import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/json.dart';
import '../domain/content_report.dart';

abstract interface class ReportRemoteDataSource {
  Future<void> send(ContentReport report);
}

/// Lentelė `content_reports`: tik įrašyti (skaityti gali tik komanda per Studio).
class SupabaseReportRemoteDataSource implements ReportRemoteDataSource {
  SupabaseReportRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> send(ContentReport report) => _client.from('content_reports').insert(report.toJson());
}

/// Neišsiųstų pranešimų eilė įrenginyje.
class ReportOutbox {
  ReportOutbox(this._prefs);

  static const _key = 'content_reports_outbox';
  final SharedPreferences _prefs;

  List<ContentReport> read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      return parseList(jsonDecode(raw), ContentReport.fromJson).toList();
    } on Object {
      return [];
    }
  }

  Future<void> write(List<ContentReport> reports) =>
      _prefs.setString(_key, jsonEncode([for (final r in reports) r.toJson()]));
}
