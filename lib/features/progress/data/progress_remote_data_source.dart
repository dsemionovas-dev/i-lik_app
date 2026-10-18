import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/lesson_attempt.dart';
import '../domain/models/user_progress.dart';

abstract interface class ProgressRemoteDataSource {
  /// Įrašo bandymą; serveris sujungia jį su esamu progresu. Idempotentiška pagal [LessonAttempt.id].
  Future<void> recordAttempt(LessonAttempt attempt);

  /// Visas prisijungusio vartotojo progresas (RLS – tik savo eilutės).
  Future<List<UserProgress>> fetchProgress();
}

/// `supabase/migrations/…_progress.sql`: RPC `record_lesson_attempt` ir
/// lentelė `user_lesson_progress`. Klientas tiesiogiai į lentelę nerašo.
class SupabaseProgressRemoteDataSource implements ProgressRemoteDataSource {
  SupabaseProgressRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<void> recordAttempt(LessonAttempt attempt) =>
      _client.rpc<dynamic>('record_lesson_attempt', params: attempt.toRpcParams());

  @override
  Future<List<UserProgress>> fetchProgress() async {
    final rows = await _client.from('user_lesson_progress').select();
    return rows.map(UserProgress.fromJson).toList(growable: false);
  }
}
