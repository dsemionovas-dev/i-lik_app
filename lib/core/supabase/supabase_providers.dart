import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

Future<void> initSupabase() async {
  if (!Env.hasSupabase) return;
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey);
}

/// `null`, kai Supabase nesukonfigūruotas (vietinis režimas).
final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => Env.hasSupabase ? Supabase.instance.client : null,
);
