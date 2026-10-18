import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF2E7D32); // miško žalia

  static ThemeData light() => ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: _seed), useMaterial3: true);

  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
    useMaterial3: true,
  );
}
