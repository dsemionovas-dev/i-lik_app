import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Perrašomas `main.dart` faile su jau inicializuotu egzemplioriumi,
/// kad jį būtų galima skaityti sinchroniškai (pvz., maršrutizatoriaus redirect'e).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Perrašyk sharedPreferencesProvider main.dart faile'),
);
