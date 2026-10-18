import 'package:flutter/material.dart';

/// Teisingo / neteisingo atsakymo spalvos, pritaikytos šviesiai ir tamsiai temai.
extension AnswerColors on ThemeData {
  Color get correctColor =>
      brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade700;

  Color get incorrectColor => colorScheme.error;
}
