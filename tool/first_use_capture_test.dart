import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/explore_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/first_class_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_rehearsal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../test/support/workout_catalog_fixture.dart';

void main() {
  testWidgets('capture first-use journey with production widgets', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> capture(String name, Widget screen, {String? scrollTo}) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            key: ValueKey(name),
            overrides: [
              authStateProvider.overrideWith(
                (_) => Stream.value(
                  screen is WorkoutEditorScreen
                      ? const AuthUser(
                          id: 'preview',
                          email: '',
                          displayName: '',
                          photoUrl: null,
                        )
                      : null,
                ),
              ),
              fixtureWorkoutDetails,
              workoutControllerProvider.overrideWith(_Workouts.new),
              accountWorkoutPreferencesProvider('preview')
                  .overrideWith((_) async => const WorkoutPreferences()),
              slideEditorRepositoryProvider.overrideWithValue(
                LocalSlideEditorRepository(SlideEditorLocalDataSource()),
              ),
              androidTvProvider.overrideWith((_) async => false),
              firstClassControllerProvider.overrideWith(_Progress.new),
              displayDevicesProvider.overrideWith((_) => Stream.value([])),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              home: screen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (screen is LoginScreen) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/login_welcome.png'),
            tester.element(find.byType(LoginScreen)),
          ),
        );
        await tester.pumpAndSettle();
      }
      if (scrollTo != null) {
        await tester.scrollUntilVisible(find.text(scrollTo), 160);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/first-use/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('01-welcome', const LoginScreen());
    await capture('02-explore', const ExploreScreen());
    await capture(
      '03-explore-action',
      const ExploreScreen(),
      scrollTo: '이 기기에서 1분 체험',
    );
    await capture(
      '04-demo',
      WorkoutRehearsalScreen(
        workout: StarterWorkout.interval.createDemo(),
        demo: true,
      ),
    );
    await capture('05-next-step', const FirstClassScreen());
    await capture(
      '06-empty-editor',
      const WorkoutEditorScreen(workoutId: 'new'),
    );
    await capture(
      '07-owned-editor',
      const WorkoutEditorScreen(workoutId: 'class_from_basics', guide: true),
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

class _Progress extends FirstClassController {
  @override
  Future<FirstClassProgress?> build() async => const FirstClassProgress(
    sessionId: 'preview',
    savedWorkoutId: 'class_from_basics',
  );
}

class _Workouts extends FixtureWorkoutController {
  final values = [
    StarterWorkout.basics.createOwned(
      const WorkoutAuthor(id: 'preview', displayName: '', photoUrl: null),
    ),
  ];
  @override
  Stream<List<Workout>> fullBuild() => Stream.value(values);
  @override
  Future<List<WorkoutSummary>> loadComplete() async =>
      values.map(summarizeWorkout).toList();
}
