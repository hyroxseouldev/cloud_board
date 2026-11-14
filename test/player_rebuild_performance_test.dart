import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'support/ui_layout_evidence.dart';

import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  for (final targets in [
    <String>[],
    ['tv'],
  ]) {
    testWidgets(
      'player image policy follows actual targets $targets, not server session id',
      (tester) async {
        final workout =
            Workout.empty(
              'w',
              const WorkoutAuthor(
                id: 'u',
                displayName: 'Coach',
                photoUrl: null,
              ),
            ).copyWith(
              modules: [
                WorkoutModule.empty('m').copyWith(name: 'Squat', beep: false),
              ],
            );
        final session = PlaybackSessionModel.fromWorkout(
          id: 's',
          ownerId: 'u',
          zoneId: 'main',
          targetDeviceIds: targets,
          workout: workout,
          stepIndex: 0,
          durationMs: 60000,
          deviceId: 'd',
        ).toEntity();
        final provider = playerControllerProvider(
          workout,
          startModule: 0,
          sessionId: 's',
          canControl: true,
        );
        final container = ProviderContainer(
          overrides: [
            accountOwnerIdProvider.overrideWith((_) => Stream.value('u')),
            activePlaybackSessionProvider.overrideWith(
              (_) => Stream.value(session),
            ),
            serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
            playbackConnectionProvider.overrideWith((_) => Stream.value(true)),
            androidTvProvider.overrideWith((_) async => true),
            provider.overrideWith(_ControlledPlayer.new),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: WorkoutPlayerScreen(
                workoutId: 'w',
                startModule: 0,
                sessionId: 's',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('미리보기 보기'),
          targets.isEmpty ? findsNothing : findsOneWidget,
        );
        expect(
          find.byType(WorkoutSlideCanvas),
          targets.isEmpty ? findsOneWidget : findsNothing,
        );
        expect(find.byType(WorkoutImage), findsNothing);
        if (targets.isNotEmpty) {
          await tester.tap(find.text('미리보기 보기'));
          await tester.pumpAndSettle();
          expect(find.byType(WorkoutSlideCanvas), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'controller row preserves decoded image through ticks and selection',
    (tester) async {
      const wakelockChannel =
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        wakelockChannel,
        (_) async =>
            const StandardMessageCodec().encodeMessage(<Object?>[null]),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          wakelockChannel,
          null,
        ),
      );
      if (layoutEvidenceDirectory.isNotEmpty) await loadLayoutFonts(tester);
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final workout =
          Workout.empty(
            'w',
            const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
          ).copyWith(
            modules: [
              for (var i = 0; i < 2; i++)
                WorkoutModule.empty('m$i')
                    .copyWith(name: 'Slide $i', imageSource: png, beep: false),
            ],
          );
      final session = PlaybackSessionModel.fromWorkout(
        id: 's',
        ownerId: 'u',
        zoneId: 'main',
        targetDeviceIds: ['tv'],
        workout: workout,
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'd',
      ).toEntity();
      final provider = playerControllerProvider(
        workout,
        startModule: 0,
        sessionId: 's',
        canControl: true,
      );
      final revisedWorkout = workout.copyWith(
        modules: [
          workout.modules.first.copyWith(
            imageSource: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
          ),
          workout.modules.last,
        ],
      );
      final revisedProvider = playerControllerProvider(
        revisedWorkout,
        startModule: 0,
        sessionId: 's',
        canControl: true,
      );
      final snapshots = StreamController<PlaybackSession>();
      addTearDown(snapshots.close);
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((_) => Stream.value('u')),
          activePlaybackSessionProvider.overrideWith((_) async* {
            yield session;
            yield* snapshots.stream;
          }),
          serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
          playbackConnectionProvider.overrideWith((_) => Stream.value(true)),
          androidTvProvider.overrideWith((_) async => true),
          provider.overrideWith(_ControlledPlayer.new),
          revisedProvider.overrideWith(_ControlledPlayer.new),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(
            key: ValueKey('row-evidence'),
            child: MaterialApp(
              home: WorkoutPlayerScreen(
                workoutId: 'w',
                startModule: 0,
                sessionId: 's',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutImage), findsNothing);
      await tester.tap(find.text('미리보기 보기'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      Finder imageFor(int index) => find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is WorkoutSlideCanvas && w.module.id == 'm$index',
        ),
        matching: find.byType(Image),
      );
      final before = tester.state(imageFor(0));
      final imageProvider = tester.widget<Image>(imageFor(0)).image;
      final controller = container.read(provider.notifier) as _ControlledPlayer;
      controller.tick(59000);
      await tester.pump();
      expect(
        tester.state(imageFor(0)),
        same(before),
        reason: 'timer tick preserves decoded image',
      );
      snapshots.add(session.copyWith(revision: session.revision + 1));
      await tester.pump();
      expect(
        tester.state(imageFor(0)),
        same(before),
        reason: 'remote revision does not recreate unchanged images',
      );
      expect(
        tester
            .widget<RawImage>(
              find.descendant(of: imageFor(0), matching: find.byType(RawImage)),
            )
            .image,
        isNotNull,
      );
      await _captureRow(tester, 'row-initial');
      for (final index in [1, 0, 1, 0]) {
        controller.selectForTest(index);
        await tester.pump();
        if (index == 1) await _captureRow(tester, 'row-selection');
        expect(
          tester.state(imageFor(0)),
          same(before),
          reason: 'selection must not remount the same visible image',
        );
        expect(tester.widget<Image>(imageFor(0)).image, same(imageProvider));
        expect(find.byType(WorkoutImageSkeleton), findsNothing);
        expect(tester.takeException(), isNull);
      }
      snapshots.add(
        session.copyWith(
          workout: revisedWorkout,
          revision: session.revision + 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(WorkoutImage),
        findsNothing,
        reason: 'changed workout invalidates the explicit preview scope',
      );
      await tester.tap(find.text('미리보기 보기'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkoutSlideCanvas>(
              find.byWidgetPredicate(
                (w) => w is WorkoutSlideCanvas && w.module.id == 'm0',
              ),
            )
            .module
            .imageSource,
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
      );
      expect(tester.state(imageFor(0)), isNot(same(before)));
      expect(
        tester.widget<Image>(imageFor(0)).image,
        isNot(same(imageProvider)),
      );
      expect(
        tester
            .widget<RawImage>(
              find.descendant(of: imageFor(0), matching: find.byType(RawImage)),
            )
            .image,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets(
    'millisecond ticks reuse the slide and timer text while gauge updates',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final workout =
          Workout.empty(
            'w',
            const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
          ).copyWith(
            modules: [
              WorkoutModule.empty('m').copyWith(name: 'Squat', beep: false),
            ],
          );
      final session = PlaybackSessionModel.fromWorkout(
        id: 's',
        ownerId: 'u',
        zoneId: 'main',
        targetDeviceIds: [],
        workout: workout,
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'd',
      ).toEntity();
      final provider = playerControllerProvider(
        workout,
        startModule: 0,
        sessionId: 's',
        canControl: false,
      );
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((_) => Stream.value('u')),
          activePlaybackSessionProvider.overrideWith(
            (ref) => Stream.value(session),
          ),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          playbackConnectionProvider.overrideWith((ref) => Stream.value(true)),
          androidTvProvider.overrideWith((ref) async => true),
          provider.overrideWith(_ControlledPlayer.new),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: WorkoutPlayerScreen(
              workoutId: 'w',
              startModule: 0,
              sessionId: 's',
              displayMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.widget<WorkoutSlideCanvas>(
        find.byType(WorkoutSlideCanvas),
      );
      final textBefore = tester.widget<Text>(
        find.byKey(const ValueKey('slide-time-text')),
      );
      final controller = container.read(provider.notifier) as _ControlledPlayer;
      for (var tick = 1; tick <= 9; tick++) {
        controller.tick(60000 - tick * 100);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          identical(
            tester.widget<WorkoutSlideCanvas>(find.byType(WorkoutSlideCanvas)),
            before,
          ),
          isTrue,
        );
        expect(
          identical(
            tester.widget<Text>(find.byKey(const ValueKey('slide-time-text'))),
            textBefore,
          ),
          isTrue,
        );
      }
      controller.tick(59000);
      await tester.pump();
      expect(find.text('0:59'), findsOneWidget);
      expect(
        identical(
          tester.widget<WorkoutSlideCanvas>(find.byType(WorkoutSlideCanvas)),
          before,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}

class _ControlledPlayer extends PlayerController {
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
    isPaused: false,
  );
  void selectForTest(int module) => state = state.copyWith(
    index: state.steps.indexWhere((step) => step.moduleIndex == module),
  );
  void tick(int remainingMs) =>
      state = state.copyWith(remainingMs: remainingMs);
}

Future<void> _captureRow(WidgetTester tester, String name) async {
  if (layoutEvidenceDirectory.isEmpty) return;
  // Capture the current frame, without a settle/decode wait that would hide a flash.
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('row-evidence')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$layoutEvidenceDirectory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
