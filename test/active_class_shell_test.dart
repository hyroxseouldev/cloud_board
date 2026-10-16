import 'dart:async';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/services/workout_media_controller.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/active_class_shell.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets(
    'playback failure shows text without support and retains diagnostics',
    (tester) async {
      final commands = _Commands();
      final sink = _Diagnostics();
      final error = StateError('수업 제어 실패');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceModeControllerProvider.overrideWith(_Mode.new),
            activePlaybackSessionProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            playbackRecoveryControllerProvider.overrideWith(_Recovery.new),
            playbackActionControllerProvider.overrideWith(() => commands),
            errorReporterProvider.overrideWithValue(ErrorReporter(sink)),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: const ActiveClassShell(
              playerVisible: false,
              child: Scaffold(body: Text('수업 화면')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      commands.fail(error);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('수업을 제어하지 못했습니다. 연결과 현재 수업 상태를 확인한 뒤 다시 시도해 주세요.'),
        findsOneWidget,
      );
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).action, isNull);
      expect(find.text('문제 문의하기'), findsNothing);
      expect(sink.events.single.error, same(error));
      expect(sink.events.single.context['action'], 'playback.action');
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(834, 1194),
  ]) {
    testWidgets(
      'minimize, browse, expand, external end at $size keeps paused session',
      (tester) async {
        final reducedMotion = ValueNotifier(size.width == 320);
        addTearDown(reducedMotion.dispose);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock'),
          (_) async => null,
        );
        final workout =
            Workout.empty(
              'w',
              const WorkoutAuthor(
                id: 'u',
                displayName: 'Coach',
                photoUrl: null,
              ),
            ).copyWith(
              name: '파일럿 수업',
              countdownSeconds: 0,
              modules: [
                WorkoutModule.empty('m').copyWith(name: '스쿼트', beep: false),
                WorkoutModule.empty('m2').copyWith(name: '런지', beep: false),
              ],
            );
        final session = PlaybackSessionModel.fromWorkout(
          id: 's',
          ownerId: 'u',
          zoneId: 'main',
          targetDeviceIds: ['tv'],
          workout: workout,
          stepIndex: 0,
          durationMs: 45000,
          deviceId: 'phone',
        ).toEntity().copyWith(status: PlaybackStatus.paused);
        final sessions = StreamController<PlaybackSession?>();
        final commands = _Commands();
        final recovery = _Recovery();
        final media = _Media();
        final container = ProviderContainer(
          overrides: [
            activePlaybackSessionProvider.overrideWith(
              (ref) => sessions.stream,
            ),
            deviceModeControllerProvider.overrideWith(_Mode.new),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            playbackConnectionProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            workoutMediaControllerProvider.overrideWith((ref) => media),
            playbackActionControllerProvider.overrideWith(() => commands),
            playbackRecoveryControllerProvider.overrideWith(() => recovery),
            androidTvProvider.overrideWith((ref) async => false),
          ],
        );
        final router = GoRouter(
          routes: [
            ShellRoute(
              builder: (_, state, child) => ActiveClassShell(
                playerVisible: state.uri.path.startsWith('/player/'),
                navigationBar: state.uri.path == '/'
                    ? const SizedBox(
                        key: ValueKey('navigation-dock'),
                        height: 56,
                      )
                    : null,
                child: child,
              ),
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, _) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => context.push('/profile'),
                        child: const Text('프로필 열기'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/profile',
                  builder: (_, _) =>
                      const Scaffold(body: Center(child: Text('프로필 페이지'))),
                ),
                GoRoute(
                  path: '/player/:id',
                  builder: (_, _) => const WorkoutPlayerScreen(
                    workoutId: 'w',
                    startModule: 0,
                    sessionId: 's',
                  ),
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: XonTheme.light,
              routerConfig: router,
              builder: (context, child) => ValueListenableBuilder<bool>(
                valueListenable: reducedMotion,
                builder: (context, reduced, _) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(size.width == 320 ? 2 : 1),
                    disableAnimations: reduced,
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final homeBefore = tester.element(find.text('프로필 열기'));
        sessions.add(session);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('expand-class')), findsOneWidget);
        expect(tester.element(find.text('프로필 열기')), same(homeBefore));
        final miniBefore = tester.element(
          find.byKey(const ValueKey('expand-class')),
        );
        final player = playerControllerProvider(workout, sessionId: 's');
        final playerOwner = container.read(player.notifier);
        final dockBefore = tester.element(
          find.byKey(const ValueKey('navigation-dock')),
        );
        reducedMotion.value = !reducedMotion.value;
        await tester.pumpAndSettle();
        reducedMotion.value = !reducedMotion.value;
        await tester.pumpAndSettle();
        expect(container.read(player.notifier), same(playerOwner));
        expect(
          tester.element(find.byKey(const ValueKey('navigation-dock'))),
          same(dockBefore),
        );
        expect(
          tester.element(find.byKey(const ValueKey('expand-class'))),
          same(miniBefore),
        );
        expect(tester.element(find.text('프로필 열기')), same(homeBefore));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('expand-class')), findsNothing);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(find.textContaining('일시정지 · 0:45'), findsOneWidget);
        double progress() => tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('mini-class-progress')),
            )
            .value!;
        // 15 seconds elapsed out of two one-minute slides.
        expect(progress(), closeTo(15 / 120, .001));
        await tester.pump(const Duration(seconds: 2));
        expect(progress(), closeTo(15 / 120, .001));
        IconButton control(String tooltip) => tester.widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == tooltip,
          ),
        );
        if (size.width >= 600) {
          expect(control('이전 슬라이드').onPressed, isNull);
          await tester.tap(find.byTooltip('다음 슬라이드'));
          await tester.pump();
          expect(commands.seeks, [1]);
          expect(container.read(player).isPaused, isTrue);
          expect(control('이전 슬라이드').onPressed, isNull);
          expect(control('다음 슬라이드').onPressed, isNull);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
          commands.finishSeek();
          await tester.pumpAndSettle();
          expect(control('다음 슬라이드').onPressed, isNull);
          expect(control('이전 슬라이드').onPressed, isNotNull);
          expect(progress(), closeTo(.5, .001));
          await tester.tap(find.byTooltip('이전 슬라이드'));
          await tester.pump();
          expect(commands.seeks, [1, 0]);
          expect(container.read(player).isPaused, isTrue);
          commands.finishSeek();
          await tester.pumpAndSettle();
          expect(control('이전 슬라이드').onPressed, isNull);
        } else {
          expect(find.byTooltip('이전 슬라이드'), findsNothing);
          expect(find.byTooltip('다음 슬라이드'), findsNothing);
        }
        sessions.add(session.copyWith(revision: session.revision + 1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('프로필 열기'));
        await tester.pumpAndSettle();
        expect(find.text('프로필 페이지'), findsOneWidget);
        expect(find.byKey(const ValueKey('expand-class')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('expand-class')));
        await tester.pumpAndSettle();
        expect(find.byTooltip('최소화'), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(recovery.resumes, 1);
        expect(find.byTooltip('다음 슬라이드').hitTestable(), findsNothing);
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('수업 동기화 중'), findsOneWidget);
        expect(find.byTooltip('다음 슬라이드').hitTestable(), findsNothing);
        recovery.finish();
        await tester.pumpAndSettle();
        expect(find.text('수업 동기화 중'), findsNothing);
        expect(find.byKey(const ValueKey('expand-class')), findsNothing);
        await tester.tap(find.byTooltip('최소화'));
        await tester.pumpAndSettle();
        expect(find.text('프로필 페이지'), findsOneWidget);
        expect(find.textContaining('일시정지 · 0:45'), findsOneWidget);
        expect(commands.ends, 0);
        expect(
          media.hides,
          0,
        ); // Screen disposal must not clear class system controls.
        final profileBefore = tester.element(find.text('프로필 페이지'));
        sessions.add(session.copyWith(status: PlaybackStatus.completed));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('expand-class')), findsNothing);
        expect(media.hides, 0);
        expect(tester.element(find.text('프로필 페이지')), same(profileBefore));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        unawaited(sessions.close());
        await tester.pump();
      },
    );
  }
}

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}

class _Commands extends PlaybackActionController {
  void fail(Object error) => state = AsyncError(error, StackTrace.current);
  int ends = 0;
  final seeks = <int>[];
  Completer<bool>? pendingSeek;
  @override
  Future<bool> seek({required int stepIndex, required int durationMs}) async {
    seeks.add(stepIndex);
    state = const AsyncLoading();
    pendingSeek = Completer<bool>();
    return pendingSeek!.future;
  }

  void finishSeek() {
    state = const AsyncData(null);
    pendingSeek!.complete(true);
  }

  @override
  AsyncValue<String?> build() => const AsyncData(null);
  @override
  Future<bool> complete() async {
    ends++;
    return true;
  }
}

class _Diagnostics implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async => events.add(event);
}

class _Media implements WorkoutMediaController {
  int hides = 0;
  @override
  Stream<WorkoutMediaCommand> get commands => const Stream.empty();
  @override
  Future<void> show(WorkoutMediaSnapshot snapshot) async {}
  @override
  Future<void> hide() async {
    hides++;
  }
}

class _Recovery extends PlaybackRecoveryController {
  int resumes = 0;
  @override
  Future<void> recover({bool restartTransport = true}) async {
    resumes++;
    state = const AsyncLoading();
  }

  void finish() {
    state = const AsyncData(null);
  }
}
