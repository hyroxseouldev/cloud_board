import 'dart:async';

import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/exploration_repository_impl.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/exploration_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/explore_screen.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/import_starter_workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_rehearsal_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_rehearsal_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _user = AuthUser(id: 'owner', email: '', displayName: '', photoUrl: null);
const _author = WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test(
    'demo timing stays separate from owned class and retry preserves edits',
    () async {
      final importer = _Importer();
      final action = ImportStarterWorkout(importer);
      for (final template in StarterWorkout.values) {
        final original = template.create(_author);
        final demo = template.createDemo();
        expect(
          demo.modules.map(workoutModuleDuration).reduce((a, b) => a + b),
          60,
        );
        expect(demo.modules.every((m) => !m.beep), isTrue);
        final owned = await action(template, _author, owned: true);
        expect(isStarterWorkout(owned.id), isFalse);
        expect(owned.id, isNot(demo.id));
        expect(
          owned.modules.map(workoutModuleDuration),
          original.modules.map(workoutModuleDuration),
        );
        importer.values[owned.id] = owned.copyWith(
          name: '수정한 수업',
          modules: [owned.modules.first.copyWith(workSeconds: 123)],
        );
        final retry = await action(template, _author, owned: true);
        expect(retry.name, '수정한 수업');
        expect(retry.modules.first.workSeconds, 123);
        final sample = await action(template, _author);
        expect(isStarterWorkout(sample.id), isTrue);
        expect(sample.modules, original.modules);
      }
      expect(importer.values.length, 6);
    },
  );

  test('exploration selection, purpose and learning persist without crossing accounts', () async {
    final users = StreamController<AuthUser?>();
    final repository = LocalExplorationRepository(SharedPreferencesAsync());
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((_) => users.stream),
        explorationRepositoryProvider.overrideWith((_) => repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await users.close();
    });
    container.listen(explorationControllerProvider, (_, _) {});
    users.add(null);
    await container.pump();
    await container.read(explorationControllerProvider.future);
    final controller = container.read(explorationControllerProvider.notifier);
    await Future.wait([
      controller.select(StarterWorkout.interval),
      controller.purpose('preparing'),
      controller.completed(StarterWorkout.interval),
    ]);
    final guest = await repository.load(null);
    expect(guest.templateKey, 'interval');
    expect(guest.purpose, 'preparing');
    expect(guest.completedTemplates, ['interval']);
    users.add(_user);
    await container.pump();
    expect(
      (await container.read(explorationControllerProvider.future))
          .completedTemplates,
      isEmpty,
    );
    await controller.beginImport(StarterWorkout.team, purpose: 'operating');
    container.invalidate(explorationControllerProvider);
    expect(
      (await container.read(explorationControllerProvider.future)).templateKey,
      'team',
    );
    expect(
      container.read(explorationControllerProvider).value?.pendingImport,
      isTrue,
    );
    await controller.imported(StarterWorkout.team);
    expect((await repository.load('owner')).pendingImport, isFalse);
    users.add(_user.copyWith(id: 'other'));
    await container.pump();
    expect(
      (await container.read(explorationControllerProvider.future)).templateKey,
      'basics',
    );
    expect((await repository.load(null)), guest);
  });

  test('local rehearsal does not claim TV success; next action follows actual readiness', () {
    const empty = FirstClassProgress(sessionId: 's');
    expect(empty.next(onlineTv: false), FirstClassNext.explore);
    final saved = empty.copyWith(savedWorkoutId: 'w');
    expect(saved.next(onlineTv: false), FirstClassNext.rehearse);
    final practiced = saved.copyWith(rehearsedWorkoutId: 'w');
    expect(practiced.completedCount, 1);
    expect(practiced.playedSessionId, isNull);
    expect(practiced.next(onlineTv: false), FirstClassNext.center);
    final ready = practiced.copyWith(centerReady: true, verifiedDeviceId: 'tv');
    expect(ready.next(onlineTv: false), FirstClassNext.connect);
    expect(ready.next(onlineTv: true), FirstClassNext.play);
    expect(
      ready.copyWith(savedWorkoutId: 'new').next(onlineTv: true),
      FirstClassNext.rehearse,
    );
    expect(
      ready.copyWith(playedSessionId: 'session').next(onlineTv: true),
      FirstClassNext.repeat,
    );
    expect(
      FirstClassProgress.fromJson({'sessionId': 'old'}).rehearsedWorkoutId,
      isNull,
    );
  });

  testWidgets(
    'public fixtures bypass onboarding, private routes and signup continuation remain guarded',
    (tester) async {
      final users = StreamController<AuthUser?>();
      var needsSetup = true;
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((_) => users.stream),
          onboardingRequiredProvider.overrideWith((_) async => needsSetup),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await users.close();
      });
      final subscription = container.listen(appRouterProvider, (_, _) {});
      addTearDown(subscription.close);
      final router = subscription.read();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox).first);
      Future<String> redirect(String path) async =>
          (await router.configuration.redirect(
            context,
            router.configuration.findMatch(Uri.parse(path)),
            redirectHistory: [],
          )).uri.toString();
      // The demo also remains available while auth is being restored.
      expect(
        await redirect('/explore/play/interval'),
        '/explore/play/interval',
      );
      final restoring = await redirect(
        '/starter-workouts?starter=team&purpose=preparing',
      );
      expect(Uri.parse(restoring).path, '/auth-loading');
      users.add(null);
      await tester.pump();
      expect(
        await redirect(restoring),
        '/login?starter=team&purpose=preparing',
      );
      for (final path in [
        '/editor/new',
        '/player/private',
        '/displays',
        '/profile',
        '/explore/play/private',
      ]) {
        expect(await redirect(path), '/login');
      }
      expect(await redirect('/explore'), '/explore');
      expect(
        await redirect('/starter-workouts?starter=team'),
        '/login?starter=team',
      );
      expect(
        await redirect('/starter-workouts?starter=https://evil.invalid'),
        '/login',
      );
      users.add(_user.copyWith(needsOnboarding: true));
      await tester.pump();
      expect(
        await redirect('/login/email?starter=team&purpose=preparing'),
        '/onboarding?starter=team&purpose=preparing',
      );
      expect(await redirect('/explore/play/team'), '/explore/play/team');
      expect(await redirect('/editor/new'), '/onboarding');
      needsSetup = false;
      container.invalidate(onboardingRequiredProvider);
      await tester.pump(const Duration(milliseconds: 1));
      await container.read(onboardingRequiredProvider.future);
      await tester.pump();
      expect(
        await redirect('/login?starter=team'),
        '/starter-workouts?starter=team',
      );
      expect(await redirect('/login?from=https://evil.invalid'), '/');
      await tester.pump();
      await tester.pump();
    },
  );

  for (final size in [const Size(320, 568), const Size(834, 1194)]) {
    testWidgets(
      'browse can be read with large text on $size without private providers',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((_) => Stream.value(null)),
            ],
            child: MaterialApp(
              theme: XonTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const ExploreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('인터벌 수업'), 200);
        await tester.pumpAndSettle();
        await tester.tap(find.text('인터벌 수업'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ExploreScreen)),
        );
        expect(
          container.read(explorationControllerProvider).value?.templateKey,
          'interval',
        );
        await tester.scrollUntilVisible(find.text('이 기기에서 1분 체험'), 180);
        await tester.pumpAndSettle();
        expect(find.text('이 기기에서 1분 체험').hitTestable(), findsOneWidget);
        expect(container.exists(playbackActionControllerProvider), isFalse);
        expect(container.exists(workoutActionControllerProvider), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'multi-slide rehearsal pauses on navigation and records only completed practice',
    (tester) async {
      var complete = 0;
      final demo = StarterWorkout.basics.createDemo();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: XonTheme.light,
            home: WorkoutRehearsalScreen(
              workout: demo,
              demo: true,
              onFinished: () => complete++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkoutRehearsalScreen)),
      );
      final first = slideRehearsalControllerProvider(demo.modules.first);
      final subscription = container.listen(first, (_, _) {});
      addTearDown(subscription.close);
      container.read(first.notifier).play();
      await tester.pump();
      await tester.ensureVisible(find.text('다음 슬라이드'));
      await tester.pump();
      await tester.tap(find.text('다음 슬라이드'));
      await tester.pump();
      expect(container.read(first).playing, isFalse);
      expect(
        tester
            .widget<WorkoutSlideCanvas>(find.byType(WorkoutSlideCanvas))
            .module
            .id,
        demo.modules[1].id,
      );
      for (var i = 0; i < 2; i++) {
        final label = i == 0 ? '다음 슬라이드' : '연습 종료';
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(complete, 0);
      expect(find.text('연습을 종료했어요'), findsOneWidget);
      await tester.tap(find.text('처음부터 다시 연습'));
      await tester.pumpAndSettle();
      for (var i = 0; i < demo.modules.length; i++) {
        container
            .read(slideRehearsalControllerProvider(demo.modules[i]).notifier)
            .seek(20000);
        await tester.pumpAndSettle();
        if (i < 2) {
          await tester.ensureVisible(find.text('다음 슬라이드'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('다음 슬라이드'));
          await tester.pumpAndSettle();
        }
      }
      expect(complete, 1);
      expect(find.text('연습을 마쳤어요'), findsOneWidget);
      expect(container.exists(playbackActionControllerProvider), isFalse);
      expect(container.exists(workoutActionControllerProvider), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Importer implements StarterWorkoutImporter {
  final values = <String, Workout>{};
  @override
  Future<Workout> importStarter(Workout workout) async =>
      values.putIfAbsent(workout.id, () => workout);
}
