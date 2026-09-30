import 'package:cloud_board/src/app/feature/onboarding/presentation/views/onboarding_screen.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/views/subscription_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_edit_gate.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/active_class_shell.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/core/widgets/web_page_frame.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/standby_settings_screen.dart';

import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/email_login_screen.dart';
import 'package:cloud_board/src/app/feature/update_news/presentation/views/update_news_screen.dart';
import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/device_mode_home_screen.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/user_profile_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/store_operations_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';

import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authRefresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => authRefresh.value++);
  ref.listen(onboardingRequiredProvider, (_, _) => authRefresh.value++);
  final workoutGuard = ExitGuard();
  final slideGuard = ExitGuard();
  final standbyGuard = ExitGuard();
  final operationsGuard = ExitGuard();
  final profileGuard = ExitGuard();
  final onboardingGuard = ExitGuard();
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final isLoginRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/login/email';
      final isLoadingRoute = state.matchedLocation == '/auth-loading';
      if (auth.isLoading) {
        if (isLoadingRoute) return null;
        return Uri(
          path: '/auth-loading',
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      final isLoggedIn = auth.value != null;
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoadingRoute) {
        final destination = Uri.tryParse(
          state.uri.queryParameters['from'] ?? '/',
        );
        if (destination == null ||
            destination.hasScheme ||
            destination.hasAuthority ||
            !destination.path.startsWith('/') ||
            destination.path == '/auth-loading' ||
            destination.path == '/login' ||
            destination.path == '/login/email') {
          return '/';
        }
        return destination.toString();
      }
      if (isLoggedIn && auth.value?.needsOnboarding == true) {
        final onboarding = ref.read(onboardingRequiredProvider);
        if (onboarding.value != false && state.uri.path != '/onboarding') {
          return '/onboarding';
        }
      }
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth-loading',
        builder: (_, _) => const AppStartupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        onExit: (_, _) => onboardingGuard.confirm(),
        builder: (_, state) => OnboardingScreen(
          editing: state.uri.queryParameters['edit'] == 'true',
          guard: onboardingGuard,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const WebPageFrame(child: LoginScreen()),
        routes: [
          GoRoute(
            path: 'email',
            builder: (_, _) => const WebPageFrame(child: EmailLoginScreen()),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ActiveClassShell(
          playerVisible: state.uri.path.startsWith('/player/'),
          homeVisible: state.uri.path == '/',
          child: WorkoutEditGate(
            workoutId:
                state.uri.pathSegments.firstOrNull == 'editor' &&
                    state.uri.pathSegments.length > 1
                ? state.uri.pathSegments[1]
                : null,
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            path: '/subscription',
            builder: (_, _) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: '/library/editor/:id',
            builder: (_, state) => SavedSlideEditorScreen(
              id: state.pathParameters['id']!,
              guard: slideGuard,
            ),
            onExit: (_, _) => slideGuard.confirm(),
          ),
          GoRoute(
            path: '/slides',
            builder: (_, state) => SlideLibraryScreen(
              initialFavoritesOnly:
                  state.uri.queryParameters['favorites'] == 'true',
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const DeviceModeHomeScreen(),
          ),
          GoRoute(
            path: '/editor/:id',
            builder: (_, state) => WorkoutEditorScreen(
              workoutId: state.pathParameters['id']!,
              guard: workoutGuard,
            ),
            onExit: (_, _) => workoutGuard.confirm(),
            routes: [
              GoRoute(
                path: 'slides/:moduleId',
                builder: (_, state) => SlideEditorScreen(
                  workoutId: state.pathParameters['id']!,
                  moduleId: state.pathParameters['moduleId']!,
                  guard: slideGuard,
                  request: state.extra is SlideEditRequest
                      ? state.extra as SlideEditRequest
                      : null,
                ),
                onExit: (_, _) => slideGuard.confirm(),
              ),
            ],
          ),
          GoRoute(
            path: '/displays',
            builder: (_, _) => const DisplaySettingsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const UserProfileScreen(),
            routes: [
              GoRoute(
                path: 'updates',
                builder: (_, _) => const UpdateNewsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        UpdateNewsDetailScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: 'edit',
                builder: (_, _) => EditUserProfileScreen(guard: profileGuard),
                onExit: (_, _) => profileGuard.confirm(),
              ),
            ],
          ),
          GoRoute(
            path: '/operations',
            builder: (_, _) => StoreOperationsScreen(guard: operationsGuard),
            onExit: (_, _) => operationsGuard.confirm(),
            routes: [
              GoRoute(
                path: 'standby',
                builder: (_, _) => StandbySettingsScreen(guard: standbyGuard),
                onExit: (_, _) => standbyGuard.confirm(),
              ),
            ],
          ),
          GoRoute(
            path: '/player/:id',
            builder: (_, state) => WorkoutPlayerScreen(
              workoutId: state.pathParameters['id']!,
              startModule:
                  int.tryParse(state.uri.queryParameters['start'] ?? '') ?? 0,
              sessionId: state.uri.queryParameters['session'],
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    authRefresh.dispose();
  });
  return router;
}
