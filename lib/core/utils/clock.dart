import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dabartinis laikas; testuose perrašomas.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
