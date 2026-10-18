import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/feedback/presentation/report_screen.dart';
import '../../features/guide/presentation/guide_card_screen.dart';
import '../../features/guide/presentation/guide_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/leagues/presentation/league_screen.dart';
import '../../features/lesson/domain/models/lesson_result.dart';
import '../../features/lesson/presentation/lesson_result_screen.dart';
import '../../features/lesson/presentation/lesson_screen.dart';
import '../../features/lesson_tree/presentation/lesson_tree_screen.dart';
import '../../features/onboarding/data/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import 'routes.dart';
import 'scaffold_with_nav_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Raktas kuriamas kartu su routeriu, kad keli egzemplioriai (pvz., testuose) nesidalintų būsena.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  // Router kuriamas vieną kartą; onboarding būsenos pokytis tik perleidžia redirect.
  final refresh = ValueNotifier<bool>(ref.read(onboardingCompletedProvider));
  ref.listen<bool>(onboardingCompletedProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final onboarded = refresh.value;
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!onboarded && !atOnboarding && !Routes.isPublic(state.matchedLocation)) return Routes.onboarding;
      if (onboarded && atOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.onboarding, builder: (context, state) => const OnboardingScreen()),

      // 4 skirtukai; kiekvienas turi savo navigacijos steką (indexedStack išlaiko būseną).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ScaffoldWithNavBar(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.tree, builder: (context, state) => const LessonTreeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.guide,
                builder: (context, state) => const GuideScreen(),
                routes: [
                  GoRoute(
                    path: ':cardId',
                    builder: (context, state) => GuideCardScreen(cardId: state.pathParameters['cardId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(path: 'settings', builder: (context, state) => const SettingsScreen()),
                  GoRoute(path: 'league', builder: (context, state) => const LeagueScreen()),
                  GoRoute(path: 'edit', builder: (context, state) => const EditProfileScreen()),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: Routes.resetPasswordPath,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ResetPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
          newPasswordOnly: state.uri.queryParameters['step'] == 'new',
        ),
      ),

      GoRoute(
        path: Routes.reportPath,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => ReportScreen(
          lessonId: state.uri.queryParameters['lesson'],
          itemId: state.uri.queryParameters['item'],
          guideCardId: state.uri.queryParameters['guide'],
        ),
      ),

      // Pamoka – viso ekrano modalas virš skirtukų juostos (root navigator).
      GoRoute(
        path: '/lesson/:lessonId',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: LessonScreen(lessonId: state.pathParameters['lessonId']!),
        ),
        routes: [
          GoRoute(
            path: 'result',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: LessonResultScreen(
                lessonId: state.pathParameters['lessonId']!,
                // `extra` dingsta atkūrus programėlę – ekranas tai apdoroja.
                result: state.extra is LessonResult ? state.extra! as LessonResult : null,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
