import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';

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
          // PRD: gidas pasiekiamas be paskyros – krizės metu nereikia registruotis.
          TextButton.icon(
            onPressed: () => context.go(Routes.guide),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Atidaryti gidą be registracijos'),
          ),
        ],
      ),
    );
  }
}
