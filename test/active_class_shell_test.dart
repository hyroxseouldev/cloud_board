import 'dart:async';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
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
  for (final size in [const Size(390, 844), const Size(834, 1194)]) {
    testWidgets(
      'minimize, browse, expand, external end at $size keeps paused session',
      (tester) async {
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
            ),
          ),
        );
        await tester.pump();
        sessions.add(session);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('expand-class')), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('expand-class')), findsNothing);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(find.textContaining('일시정지 · 0:45'), findsOneWidget);
        IconButton control(String tooltip) => tester.widget<IconButton>(
          find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == tooltip,
          ),
        );
        final player = playerControllerProvider(workout, sessionId: 's');
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
        await tester.tap(find.byTooltip('이전 슬라이드'));
        await tester.pump();
        expect(commands.seeks, [1, 0]);
        expect(container.read(player).isPaused, isTrue);
        commands.finishSeek();
        await tester.pumpAndSettle();
        expect(control('이전 슬라이드').onPressed, isNull);
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
        expect(find.text('최신 수업 상태를 확인하고 있습니다…'), findsOneWidget);
        expect(find.byTooltip('다음 슬라이드').hitTestable(), findsNothing);
        recovery.finish();
        await tester.pumpAndSettle();
        expect(find.text('최신 수업 상태를 확인하고 있습니다…'), findsNothing);
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
        sessions.add(session.copyWith(status: PlaybackStatus.completed));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('expand-class')), findsNothing);
        expect(media.hides, 0);
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
  Future<void> recover() async {
    resumes++;
    state = const AsyncLoading();
  }

  void finish() {
    state = const AsyncData(null);
  }
}
