import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/placeholder_body.dart';
import '../../auth/data/auth_repository.dart';
import '../data/onboarding_controller.dart';

/// TODO: kurso pasirinkimas, dienos tikslas, priminimai.
/// Paskyra nereikalinga: sukuriamas svečias, kurį vėliau galima susieti su el. paštu.
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
            onPressed: () {
              // Svečias kuriamas fone: be ryšio bus sukurtas per pirmą sinchronizaciją.
              unawaited(ref.read(authRepositoryProvider).ensureSignedIn().then<void>((_) {}, onError: (_) {}));
              ref.read(onboardingCompletedProvider.notifier).complete();
            },
            child: const Text('PRADĖTI'),
          ),
        ],
      ),
    );
  }
}
