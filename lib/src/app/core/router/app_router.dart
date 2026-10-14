import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/exploration_controller.dart';
import 'package:cloud_board/src/app/feature/support/presentation/views/support_screen.dart';
import 'package:cloud_board/src/app/core/router/main_tab_page.dart';
import 'package:cloud_board/src/app/core/widgets/main_navigation_dock.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/more_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/first_class_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/explore_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/exploration_routes.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/starter_workouts_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/first_tv_connection_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/onboarding_screen.dart';
import 'package:cloud_board/src/app/feature/billing/presentation/views/subscription_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_edit_gate.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/active_class_shell.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_page.dart';
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
import 'package:cloud_board/src/app/feature/auth/presentation/views/auth_entry_screen.dart';
import 'package:cloud_board/src/app/core/router/auth_entry_routes.dart';
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
  final mainNavigationKey = GlobalKey<StatefulNavigationShellState>();
  String? entryOwnerId;
  var entryOwnerChanged = false;
  ref.listen(authStateProvider, (_, next) {
    final id = next.value?.id;
    if (entryOwnerId != null && id != null && id != entryOwnerId) {
      entryOwnerChanged = true;
    }
    authRefresh.value++;
  });
  ref.listen(onboardingRequiredProvider, (_, _) => authRefresh.value++);
  ref.listen(explorationControllerProvider, (_, _) => authRefresh.value++);
  final workoutGuard = ExitGuard();
  final slideGuard = ExitGuard();
  final imageCreationGuard = ExitGuard();
  final standbyGuard = ExitGuard();
  final operationsGuard = ExitGuard();
  final profileGuard = ExitGuard();
  final onboardingGuard = ExitGuard();
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      if (isExplorationPath(state.uri.path)) return null;
      // Support remains reachable when sign-in/onboarding itself fails. The
      // form requires a signed-in account before enabling server submission.
      if (state.uri.path == '/support') return null;
      final auth = ref.read(authStateProvider);
      final isLoginRoute =
          state.uri.path == '/login' || state.uri.path == '/login/email';
      final isLoadingRoute = state.uri.path == '/auth-loading';
      final isOnboardingRoute = state.uri.path == '/onboarding';
      final explicitOnboarding =
          isOnboardingRoute &&
          (state.uri.queryParameters['verify'] == 'true' ||
              state.uri.queryParameters['edit'] == 'true');
      final isEntryRoute = isLoginRoute || isLoadingRoute || isOnboardingRoute;
      if (isEntryRoute) entryOwnerId ??= auth.value?.id;
      if (entryOwnerChanged &&
          isEntryRoute &&
          state.uri.queryParameters.containsKey('from')) {
        // Clear the route itself as well as the automatic return decision: the
        // onboarding completion button must not inherit another owner's target.
        final query = {...state.uri.queryParameters}..remove('from');
        return state.uri.replace(queryParameters: query).toString();
      }
      final original = isEntryRoute
          ? (explicitOnboarding
                ? state.uri.toString()
                : entryReturnLocation(state.uri.queryParameters['from']))
          : state.uri.toString();
      final originalUri = original == null ? null : Uri.parse(original);
      final starter = starterFromKey(
        state.uri.queryParameters['starter'] ??
            originalUri?.queryParameters['starter'],
      );
      final purpose = explorationPurpose(
        state.uri.queryParameters['purpose'] ??
            originalUri?.queryParameters['purpose'],
      );
      final fallback = starterLocation(
        starter == null ? '/' : '/starter-workouts',
        starter,
        purpose: purpose,
      );
      var destination = entryOwnerChanged ? fallback : original ?? fallback;
      String enter(String path) {
        entryOwnerId ??= auth.value?.id;
        if (path == '/onboarding' &&
            Uri.parse(destination).path == '/onboarding') {
          return destination;
        }
        final location = starterLocation(path, starter, purpose: purpose);
        return destination == fallback
            ? location
            : withEntryReturn(location, destination);
      }

      if (auth.isLoading || auth.hasError) {
        return isLoadingRoute ? null : enter('/auth-loading');
      }
      final isLoggedIn = auth.value != null;
      if (!isLoggedIn) {
        return isLoginRoute ? null : enter('/login');
      }
      if (auth.value?.needsOnboarding == true) {
        final onboarding = ref.read(onboardingRequiredProvider);
        // AsyncValue can retain the previous account's ready value/error while
        // refreshing. Neither is a current server decision.
        if (onboarding.isLoading || onboarding.hasError) {
          return isLoadingRoute || isOnboardingRoute
              ? null
              : enter('/auth-loading');
        }
        if (onboarding.value != false) {
          return isOnboardingRoute ? null : enter('/onboarding');
        }
      }
      if (isOnboardingRoute) {
        if (explicitOnboarding || ref.read(onboardingCompletionProvider)) {
          return null;
        }
      }
      if (isEntryRoute) {
        // This local continuation used to be restored by OnboardingScreen.
        // Explicit URLs take priority, and stale account data is never resumed.
        if (!entryOwnerChanged && original == null && starter == null) {
          final exploration = ref.read(explorationControllerProvider);
          if (exploration.isLoading) {
            return isLoadingRoute ? null : enter('/auth-loading');
          }
          final progress = exploration.hasError ? null : exploration.value;
          final saved = progress?.pendingImport == true
              ? starterFromKey(progress?.templateKey)
              : null;
          if (saved != null) {
            destination = starterLocation(
              '/starter-workouts',
              saved,
              purpose: purpose ?? progress?.purpose,
            );
          }
        }
        entryOwnerId = null;
        entryOwnerChanged = false;
        return destination;
      }
      entryOwnerId = null;
      entryOwnerChanged = false;
      return null;
    },
    routes: [
      GoRoute(
        path: '/explore',
        builder: (_, state) => ExploreScreen(
          initialTemplate: starterFromKey(state.uri.queryParameters['starter']),
          initialPurpose: explorationPurpose(
            state.uri.queryParameters['purpose'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'play/:template',
            builder: (_, state) {
              final template = starterFromKey(state.pathParameters['template']);
              return template == null
                  ? const ExploreScreen()
                  : ExploreDemoScreen(
                      template: template,
                      purpose: explorationPurpose(
                        state.uri.queryParameters['purpose'],
                      ),
                    );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/auth-loading',
        builder: (_, _) => const AuthEntryScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        onExit: (_, _) => onboardingGuard.confirm(),
        builder: (_, state) => OnboardingScreen(
          returnTo: entryReturnLocation(state.uri.queryParameters['from']),
          editing: state.uri.queryParameters['edit'] == 'true',
          verifyPhone: state.uri.queryParameters['verify'] == 'true',
          guard: onboardingGuard,
          starter: starterFromKey(state.uri.queryParameters['starter']),
          purpose: explorationPurpose(state.uri.queryParameters['purpose']),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) => WebPageFrame(
          child: LoginScreen(
            returnTo: entryReturnLocation(state.uri.queryParameters['from']),
            starter: starterFromKey(state.uri.queryParameters['starter']),
            purpose: explorationPurpose(state.uri.queryParameters['purpose']),
          ),
        ),
        routes: [
          GoRoute(
            path: 'email',
            builder: (_, state) => WebPageFrame(
              child: EmailLoginScreen(
                returnTo: entryReturnLocation(
                  state.uri.queryParameters['from'],
                ),
                starter: starterFromKey(state.uri.queryParameters['starter']),
                purpose: explorationPurpose(
                  state.uri.queryParameters['purpose'],
                ),
              ),
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) {
          final destination = MainDestination.forPath(state.uri.path);
          return ActiveClassShell(
            playerVisible: state.uri.path.startsWith('/player/'),
            homeVisible: state.uri.path == '/',
            navigationBar: destination == null
                ? null
                : MainNavigationDock(
                    selected: destination,
                    onSelected: (next) {
                      if (next == destination) return;
                      FocusManager.instance.primaryFocus?.unfocus();
                      mainNavigationKey.currentState?.goBranch(next.index);
                    },
                  ),
            child: WorkoutEditGate(
              workoutId:
                  state.uri.pathSegments.firstOrNull == 'editor' &&
                      state.uri.pathSegments.length > 1
                  ? state.uri.pathSegments[1]
                  : null,
              child: child,
            ),
          );
        },
        routes: [
          StatefulShellRoute.indexedStack(
            key: mainNavigationKey,
            builder: (_, _, navigationShell) => navigationShell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const MainTabPage(
                      home: true,
                      child: DeviceModeHomeScreen(),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/slides',
                    builder: (_, state) => MainTabPage(
                      child: SlideLibraryScreen(
                        asMainTab: true,
                        initialFavoritesOnly:
                            state.uri.queryParameters['favorites'] == 'true',
                      ),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/displays',
                    builder: (_, _) => const MainTabPage(
                      child: DisplaySettingsScreen(asMainTab: true),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/more',
                    builder: (_, _) => const MainTabPage(child: MoreScreen()),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/support',
            builder: (_, state) => SupportScreen(
              initialAccountId: state.extra is Map<String, Object?>
                  ? (state.extra as Map<String, Object?>)['_supportOwnerId']
                        as String?
                  : null,
              initialDiagnostics: state.extra is Map<String, Object?>
                  ? state.extra as Map<String, Object?>
                  : const {},
            ),
          ),
          GoRoute(
            path: '/first-class',
            builder: (_, _) => const FirstClassScreen(),
          ),
          GoRoute(
            path: '/starter-workouts',
            builder: (_, state) => StarterWorkoutsScreen(
              purpose: explorationPurpose(state.uri.queryParameters['purpose']),
              initialTemplate: starterFromKey(
                state.uri.queryParameters['starter'],
              ),
            ),
          ),
          GoRoute(
            path: '/displays/connect',
            builder: (_, _) => const FirstTvConnectionScreen(),
          ),
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
            path: '/editor/:id',
            builder: (_, state) => WorkoutEditorScreen(
              workoutId: state.pathParameters['id']!,
              guard: workoutGuard,
              guide: state.uri.queryParameters['guide'] == 'true',
            ),
            onExit: (_, _) => workoutGuard.confirm(),
            routes: [
              GoRoute(
                path: 'images/create',
                builder: (_, _) => AiSlidesPage(guard: imageCreationGuard),
                onExit: (_, _) => imageCreationGuard.confirm(),
              ),
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
