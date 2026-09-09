import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/standby_settings_screen.dart';

import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/device_mode_home_screen.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/user_profile_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/store_operations_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final auth = ref.watch(authStateProvider);
  final workoutGuard = ExitGuard();
  final slideGuard = ExitGuard();
  final standbyGuard = ExitGuard();
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = auth.value != null;
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
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
      GoRoute(path: '/profile', builder: (_, _) => const UserProfileScreen()),
      GoRoute(
        path: '/operations',
        builder: (_, _) => const StoreOperationsScreen(),
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
  );
}
