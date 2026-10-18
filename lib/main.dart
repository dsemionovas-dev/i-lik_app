import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/shared_preferences_provider.dart';
import 'core/supabase/supabase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Asinchroninės priklausomybės paruošiamos prieš pirmą kadrą,
  // kad provideriai jas galėtų skaityti sinchroniškai.
  final (prefs, _) = await (SharedPreferences.getInstance(), initSupabase()).wait;

  runApp(ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)], child: const IslikApp()));
}
