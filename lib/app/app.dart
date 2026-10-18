import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/progress/application/progress_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class IslikApp extends ConsumerStatefulWidget {
  const IslikApp({super.key});

  @override
  ConsumerState<IslikApp> createState() => _IslikAppState();
}

class _IslikAppState extends ConsumerState<IslikApp> {
  /// Grįžus į programėlę (dažnai – atsiradus ryšiui) išsiunčiami sukaupti bandymai.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => unawaited(ref.read(progressControllerProvider.notifier).syncNow()),
  );

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
