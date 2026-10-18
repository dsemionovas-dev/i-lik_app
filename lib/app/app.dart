import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/progress/application/progress_controller.dart';
import 'router/app_router.dart';
import 'router/routes.dart';
import 'theme/app_theme.dart';

class IslikApp extends ConsumerStatefulWidget {
  const IslikApp({super.key});

  @override
  ConsumerState<IslikApp> createState() => _IslikAppState();
}

class _IslikAppState extends ConsumerState<IslikApp> {
  /// Grįžus į programėlę (dažnai – atsiradus ryšiui) išsiunčiami sukaupti bandymai.
  late final _lifecycle = AppLifecycleListener(onResume: _onResume);

  void _onResume() {
    unawaited(ref.read(progressControllerProvider.notifier).syncNow());
    // El. paštas galėjo būti patvirtintas naršyklėje – atnaujinam vartotoją.
    unawaited(ref.read(authRepositoryProvider).refreshUser().then<void>((_) {}, onError: (_) {}));
  }

  @override
  void initState() {
    super.initState();
    _lifecycle; // inicializuojam
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Progresas įkeliamas ir sinchronizuojamas paleidus programėlę.
    ref.listen(progressControllerProvider, (_, _) {});
    final router = ref.watch(appRouterProvider);
    // Atidaryta slaptažodžio atstatymo nuoroda iš laiško.
    ref.listen(passwordRecoveryProvider, (_, next) {
      if (next.hasValue) router.go(Routes.newPassword);
    });
    return MaterialApp.router(
      title: 'Išlik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      locale: const Locale('lt'),
      supportedLocales: const [Locale('lt')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
