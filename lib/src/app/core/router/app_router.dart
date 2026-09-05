import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../feature/auth/presentation/controllers/auth_controller.dart';
import '../../feature/auth/presentation/views/login_screen.dart';
import '../../feature/device/presentation/views/device_mode_home_screen.dart';
import '../../feature/profile/presentation/views/user_profile_screen.dart';
import '../../feature/workouts/presentation/views/workout_editor_screen.dart';
import '../../feature/workouts/presentation/views/workout_player_screen.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final auth = ref.watch(authStateProvider);
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
        builder: (_, state) =>
            WorkoutEditorScreen(workoutId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (_, _) => const UserProfileScreen()),
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
