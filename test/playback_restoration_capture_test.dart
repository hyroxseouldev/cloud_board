// Deterministic widget fixture: fake session/controller, local generated PNG,
// no Firebase SDK, account login, real TV, or native device execution.
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/ui_layout_evidence.dart';

void main() {
  testWidgets('local fixture captures controller and authored countdown', (
    tester,
  ) async {
    if (layoutEvidenceDirectory.isEmpty) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
    await loadLayoutFonts(tester);
    final source = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 640, 360),
        Paint()..color = const Color(0xFF327F91),
      );
      canvas.drawCircle(
        const Offset(480, 80),
        150,
        Paint()..color = const Color(0xFFEAA566),
      );
      canvas.drawCircle(
        const Offset(160, 320),
        200,
        Paint()..color = const Color(0xFF244957),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(640, 360);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final source =
          'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
      image.dispose();
      picture.dispose();
      return source;
    });
    final workout =
        Workout.empty(
          'fixture',
          const WorkoutAuthor(
            id: 'fake',
            displayName: 'Fixture',
            photoUrl: null,
          ),
        ).copyWith(
          name: '로컬 테스트 수업',
          countdownImageSource: source!,
          countdownBackgroundColor: 0xFF3F245C,
          modules: [
            for (var i = 0; i < 4; i++)
              WorkoutModule.empty('slide-$i').copyWith(
                name: '테스트 슬라이드 ${i + 1}',
                imageSource: source,
                beep: false,
              ),
          ],
        );
    final session = PlaybackSessionModel.fromWorkout(
      id: 'fixture-session',
      ownerId: 'fake',
      zoneId: 'main',
      targetDeviceIds: ['fake-tv'],
      workout: workout,
      stepIndex: 0,
      durationMs: 60000,
      deviceId: 'fixture',
    ).toEntity();
    final provider = playerControllerProvider(
      workout,
      startModule: 0,
      sessionId: session.id,
      canControl: true,
    );
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((_) => Stream.value('fake')),
        activePlaybackSessionProvider.overrideWith(
          (_) => Stream.value(session),
        ),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        playbackConnectionProvider.overrideWith((_) => Stream.value(true)),
        androidTvProvider.overrideWith((_) async => true),
        provider.overrideWith(_FixturePlayer.new),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            theme: XonTheme.light,
            home: WorkoutPlayerScreen(
              workoutId: workout.id,
              startModule: 0,
              sessionId: session.id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await captureLayout(
      tester,
      find.byKey(const ValueKey('capture')),
      'custom-countdown-fake-session',
    );
    (container.read(provider.notifier) as _FixturePlayer).begin();
    await tester.pump();
    await captureLayout(
      tester,
      find.byKey(const ValueKey('capture')),
      'controller-fake-session',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}

class _FixturePlayer extends PlayerController {
  @override
  PlayerState build(
    Workout workout, {
    int startModule = 0,
    String? sessionId,
    bool canControl = true,
  }) => PlayerState(
    steps: buildPlayerSteps(workout),
    index: 0,
    remainingMs: 60000,
    countdownMs: 5000,
    isPaused: false,
  );
  void begin() => state = state.copyWith(countdownMs: 0);
}
