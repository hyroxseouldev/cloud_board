import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';

final workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
);

void main() {
  const png =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
  for (final customImage in [false, true]) {
    testWidgets(
      'countdown preserves authored image/color and overlay: image=$customImage',
      (tester) async {
        final configured = workout.copyWith(
          countdownImageSource: customImage ? png : '',
          countdownBackgroundColor: 0xFF3F245C,
        );
        Future<void> mount(Workout value) async {
          await tester.pumpWidget(
            MaterialApp(home: WorkoutCountdown(workout: value, seconds: 5)),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
        }

        Color overlay() => tester
            .widget<ColoredBox>(find.byKey(const ValueKey('countdown-overlay')))
            .color;
        await mount(configured);
        expect(
          find.byType(WorkoutImage),
          customImage ? findsOneWidget : findsNothing,
        );
        expect(
          overlay(),
          customImage
              ? Colors.black.withValues(alpha: .54)
              : const Color(0xFF3F245C),
        );
        if (customImage) {
          expect(
            tester.widget<WorkoutImage>(find.byType(WorkoutImage)).source,
            png,
          );
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image,
            isNotNull,
          );
        }
        await mount(
          configured.copyWith(
            countdownAppearance: const CountdownAppearance(
              overlayColor: 0xFF114422,
              overlayOpacity: .3,
              numberColor: 0xFFFFDD00,
              numberFormat: CountdownNumberFormat.clock,
              numberScale: 1.4,
              numberShadow: true,
              showReady: false,
              showTitle: false,
            ),
          ),
        );
        expect(overlay(), const Color(0xFF114422).withValues(alpha: .3));
        expect(find.text('00:05'), findsOneWidget);
        expect(find.text('준비하세요'), findsNothing);
        final text = tester.element(find.text('00:05'));
        expect(DefaultTextStyle.of(text).style.color, const Color(0xFFFFDD00));
        expect(DefaultTextStyle.of(text).style.shadows, isNotEmpty);
        await mount(
          configured.copyWith(
            countdownAppearance: const CountdownAppearance(
              overlayEnabled: false,
            ),
          ),
        );
        expect(find.byKey(const ValueKey('countdown-overlay')), findsNothing);
        expect(
          find.byType(WorkoutImage),
          customImage ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'countdown retains the legacy slide-image fallback and color overlay',
    (tester) async {
      final configured = workout.copyWith(
        countdownBackgroundColor: 0xFFEFEFEF,
        modules: [
          WorkoutModule.empty('m')
              .copyWith(imageSource: png, coverImage: false),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: WorkoutCountdown(workout: configured, seconds: 3)),
      );
      expect(
        tester.widget<WorkoutImage>(find.byType(WorkoutImage)).source,
        png,
      );
      expect(
        tester.widget<WorkoutImage>(find.byType(WorkoutImage)).fit,
        BoxFit.contain,
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('countdown-overlay')))
            .color,
        const Color(0xFFEFEFEF),
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('3'))).style.color,
        Colors.black,
      );
    },
  );

  for (final seconds in [0, 17, 60]) {
    test(
      'new session bypasses briefing and starts with $seconds second countdown',
      () async {
        final model = PlaybackSessionModel.fromWorkout(
          id: 'session',
          ownerId: 'u',
          zoneId: 'main',
          targetDeviceIds: ['tv'],
          workout: workout.copyWith(countdownSeconds: seconds),
          stepIndex: 0,
          durationMs: 60000,
          deviceId: 'controller',
        );
        final local = _Local(model);
        final remote = _Remote(model);
        final started = await PlaybackRepositoryImpl(remote, local, 'u').start(
          workout: workout.copyWith(countdownSeconds: seconds),
          targetDeviceIds: ['tv'],
          stepIndex: 0,
          durationMs: 60000,
          deviceId: 'controller',
        );
        expect(started.briefing, isFalse);
        expect(started.startDelayMs, seconds * 1000);
        expect(local.model.startDelayMs, seconds * 1000);
        expect(started.targetDeviceIds, ['tv']);
      },
    );

    test(
      'begin sends $seconds seconds to the current briefing session',
      () async {
        final model = PlaybackSessionModel.fromWorkout(
          id: 'session',
          ownerId: 'u',
          zoneId: 'main',
          targetDeviceIds: ['tv'],
          workout: workout.copyWith(countdownSeconds: seconds),
          stepIndex: 0,
          durationMs: 60000,
          deviceId: 'controller',
          briefing: true,
        );
        final local = _Local(model);
        final remote = _Remote(model);
        await PlaybackRepositoryImpl(
          remote,
          local,
          'u',
        ).begin(deviceId: 'controller');
        expect(remote.delay, seconds * 1000);
        expect(
          local.delay,
          isNull,
        ); // No optimistic cache write before acknowledgement.
        expect(remote.sessionId, 'session');
        expect(remote.briefingRequired, isTrue);
      },
    );
  }
  testWidgets(
    'editing partial colors keeps last valid color and countdown can be disabled',
    (tester) async {
      var draft = workout;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  child: CountdownSettings(
                    workout: draft,
                    onChanged: (v) => setState(() => draft = v),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final field = find.byType(TextFormField).last;
      await tester.enterText(field, '#12');
      await tester.pump();
      expect(draft.countdownBackgroundColor, 0xFF000000);
      expect(tester.takeException(), isNull);
      await tester.enterText(field, '#FFFFFF');
      await tester.pump();
      expect(draft.countdownBackgroundColor, 0xFFFFFFFF);
      await tester.enterText(
        find.byKey(const ValueKey('countdown-seconds')),
        '0',
      );
      await tester.pump();
      expect(draft.countdownSeconds, 0);
      expect(find.text('바로 시작 (카운트다운 없음)'), findsOneWidget);
    },
  );
}

class _Local implements PlaybackSessionLocalDataSource {
  _Local(this.model);
  PlaybackSessionModel model;
  int? delay;
  @override
  Future<PlaybackSessionModel?> load() async => model;
  @override
  Future<void> save(PlaybackSessionModel value) async {
    model = value;
  }

  @override
  Future<PlaybackSessionModel?> update({
    required String status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
  }) async {
    delay = startDelayMs;
    return model;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Remote implements PlaybackRealtimeDataSource {
  _Remote(this.model);
  final PlaybackSessionModel model;
  @override
  bool get canUseAccount => true;
  @override
  Future<PlaybackSessionModel> start(
    PlaybackSessionModel value, {
    bool scheduled = false,
    int? scheduledAtMs,
    void Function()? ensureCurrent,
  }) async => value;
  int? delay;
  String? sessionId;
  bool? briefingRequired;
  @override
  Future<PlaybackSessionModel> update({
    required String? status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
    bool finishTimer = false,
    required String expectedSessionId,
    required int expectedRevision,
  }) async {
    delay = startDelayMs;
    sessionId = expectedSessionId;
    briefingRequired = requireBriefing;
    return model;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
