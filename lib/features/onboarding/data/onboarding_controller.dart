import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/shared_preferences_provider.dart';

/// Ar vartotojas jau praėjo onboardingą. Maršrutizatorius jo klauso.
class OnboardingController extends Notifier<bool> {
  static const _key = 'onboarding_completed';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> complete() async {
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
    state = true;
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
