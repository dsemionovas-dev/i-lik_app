import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/placeholder_body.dart';
import '../data/onboarding_controller.dart';

/// TODO: kurso pasirinkimas, dienos tikslas, priminimai, paskyra / svečio režimas.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: PlaceholderBody(
        title: 'Sveiki atvykę į Išlik',
        children: [
          // Redirect'as pats nuveda į /home, kai būsena pasikeičia.
          FilledButton(
            onPressed: () => ref.read(onboardingCompletedProvider.notifier).complete(),
            child: const Text('PRADĖTI'),
          ),
        ],
      ),
    );
  }
}
