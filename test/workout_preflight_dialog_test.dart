import 'dart:async';

import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_preferences_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_preparation_actions.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

import 'dart:convert';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  for (final modern in [false, true]) {
    testWidgets(
      'account countdown preferences prepare and verify without a manual TV check (modern=$modern)',
      (tester) async {
        final raw =
            Workout.empty(
              'w',
              const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
            ).copyWith(
              name: '수업',
              modules: [WorkoutModule.empty('m').copyWith(name: '운동')],
            );
        final defaults = WorkoutPreferences.fromWorkout(raw);
        final preferences = _Preferences()
          ..value = defaults.copyWith(
            countdown: defaults.countdown.copyWith(
              appearance: defaults.countdown.appearance.copyWith(
                numberScale: 0.5,
              ),
            ),
          );
        final effective = preferences.value!.applyTo(raw);
        final repository = _PreparationRepository();
        final device = DisplayDevice(
          id: 'a',
          name: '아이패드',
          zoneId: 'main',
          zoneName: '',
          online: true,
          lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
          currentSessionId: null,
          acknowledgedRevision: 0,
          paired: true,
          playbackProtocol: 5,
          preparationProtocol: modern ? 1 : 0,
        );
        WorkoutPreflightSelection? selection;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutPreferencesRepositoryProvider.overrideWith(
                (_) => preferences,
              ),
              displayDevicesProvider.overrideWith(
                (_) => Stream.value([device]),
              ),
              serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
              displayPreparationRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
            child: MaterialApp(
              theme: XonTheme.light,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async =>
                        selection = await showWorkoutPreflight(context, raw),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(find.text('구형 TV 화면을 직접 확인했어요'), findsNothing);
        expect(
          find.byType(CheckboxListTile),
          findsOneWidget,
          reason: 'Only the playback target remains selectable.',
        );
        final start = find.widgetWithText(FilledButton, '수업 시작');
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(
          selection!.preparation!.manifestHash,
          preparationFingerprint(effective, ['a']),
        );
        expect(
          selection!.preparation!.manifestHash,
          isNot(preparationFingerprint(raw, ['a'])),
        );
        final verify = DisplayPreparationActions(
          repository,
          _Devices([device]),
        );
        await verify.verifyStart(
          await WorkoutPreferencesActions(preferences).apply(raw, fresh: true),
          ['a'],
          selection!.preparation,
        );
        preferences.value = defaults;
        await expectLater(
          verify.verifyStart(
            await WorkoutPreferencesActions(preferences)
                .apply(raw, fresh: true),
            ['a'],
            selection!.preparation,
          ),
          throwsStateError,
        );
        expect(preferences.freshReads, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'settings failure blocks preparation and retries with readable feedback',
    (tester) async {
      final raw = Workout.empty(
        'w',
        const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
      ).copyWith(name: '수업', modules: [WorkoutModule.empty('m')]);
      final preferences = _Preferences()
        ..error = StateError('PRIVATE_SETTINGS_ERROR');
      final sink = _PreflightDiagnostics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutPreferencesRepositoryProvider.overrideWith(
              (_) => preferences,
            ),
            errorReporterProvider.overrideWithValue(ErrorReporter(sink)),
            displayDevicesProvider.overrideWith((_) => Stream.value([])),
          ],
          child: MaterialApp(home: WorkoutPreflightDialog(workout: raw)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('수업 설정을 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('PRIVATE_SETTINGS_ERROR'), findsNothing);
      expect(find.text('수업 시작'), findsNothing);
      expect(
        sink.events.single.context['action'],
        'workout.preflight.preferences',
      );
      preferences.error = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('수업 시작'), findsOneWidget);
      expect(preferences.freshReads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing while preferences load cannot access a disposed provider',
    (tester) async {
      final preferences = _Preferences()..pending = Completer<void>();
      final raw = Workout.empty(
        'w',
        const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutPreferencesRepositoryProvider.overrideWith(
              (_) => preferences,
            ),
          ],
          child: MaterialApp(home: WorkoutPreflightDialog(workout: raw)),
        ),
      );
      await tester.pump();
      expect(find.text('최신 수업 설정을 확인하고 있어요.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      preferences.error = StateError('PRIVATE_LATE_SETTINGS_ERROR');
      preferences.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TV request error retains manual exclusion guidance and retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _PreparationRepository()..failRequest = true;
    final workout =
        Workout.empty(
          'w',
          const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
        ).copyWith(
          name: '수업',
          modules: [WorkoutModule.empty('m').copyWith(name: '스쿼트')],
        );
    final device = DisplayDevice(
      id: 'a',
      name: 'TV a',
      zoneId: 'main',
      zoneName: '',
      online: true,
      lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
      currentSessionId: null,
      acknowledgedRevision: 0,
      paired: true,
      preparationProtocol: 1,
      playbackProtocol: 5,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutPreferencesRepositoryProvider.overrideWith(
            (_) => _Preferences(),
          ),
          displayDevicesProvider.overrideWith((_) => Stream.value([device])),
          serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
          displayPreparationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          home: WorkoutPreflightDialog(workout: workout),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('TV 준비 요청을 보내지 못했어요.'), findsOneWidget);
    expect(
      find.textContaining('준비되지 않은 TV는 체크를 해제하면 제외하고 수업을 시작할 수 있어요.'),
      findsOneWidget,
    );
    expect(find.textContaining('PRIVATE_REQUEST_ERROR'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'TV a'),
          )
          .value,
      isTrue,
    );
    repository.failRequest = false;
    await tester.tap(find.text('TV 준비 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('TV 1대 중 1대 준비 완료'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one failed TV blocks start until explicitly excluded and new candidate acknowledged',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _PreparationRepository();
      WorkoutPreflightSelection? selected;
      final workout =
          Workout.empty(
            'w',
            const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
          ).copyWith(
            name: '수업',
            modules: [WorkoutModule.empty('m').copyWith(name: '스쿼트')],
          );
      final now = DateTime.now().millisecondsSinceEpoch;
      final devices = ['a', 'b']
          .map(
            (id) => DisplayDevice(
              id: id,
              name: 'TV $id',
              zoneId: 'main',
              zoneName: '',
              online: true,
              lastSeenAtMs: now,
              currentSessionId: 'old-session',
              acknowledgedRevision: 999,
              paired: true,
              preparationProtocol: 1,
              playbackProtocol: 5,
            ),
          )
          .toList();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutPreferencesRepositoryProvider.overrideWith(
              (_) => _Preferences(),
            ),
            displayDevicesProvider.overrideWith((ref) => Stream.value(devices)),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            displayPreparationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      selected = await showWorkoutPreflight(context, workout),
                  child: const Text('준비 열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('준비 열기'));
      await tester.pumpAndSettle();
      expect(find.text('TV 2대 중 1대 준비 완료'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
            .onPressed,
        isNull,
      );
      final first = repository.value!.sessionId;
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'TV 준비 다시 확인'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('TV 준비 다시 확인'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(repository.value!.sessionId, isNot(first));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
            .onPressed,
        isNull,
      );
      final both = repository.value!.manifestHash;
      final second = find.widgetWithText(CheckboxListTile, 'TV b');
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repository.value!.targetDeviceIds, ['a']);
      expect(repository.value!.manifestHash, isNot(both));
      expect(find.text('TV 1대 중 1대 준비 완료'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, '수업 시작'));
      await tester.pumpAndSettle();
      expect(selected!.targetDeviceIds, ['a']);
      expect(
        selected!.preparation!.manifestHash,
        repository.value!.manifestHash,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('이미지 준비 오류는 원문을 숨기고 진단 정보와 복구 안내를 유지한다', (tester) async {
    final sink = _PreflightDiagnostics();
    final workout =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'user',
            displayName: 'Tester',
            photoUrl: null,
          ),
        ).copyWith(
          modules: [
            WorkoutModule.empty('module').copyWith(
              imageSource: 'data:image/png;base64,TECHNICAL_PRIVATE%%',
            ),
          ],
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutPreferencesRepositoryProvider.overrideWith(
            (_) => _Preferences(),
          ),
          displayDevicesProvider.overrideWith((ref) => Stream.value(const [])),
          errorReporterProvider.overrideWithValue(ErrorReporter(sink)),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: WorkoutPreflightDialog(workout: workout),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이미지 준비 실패'), findsOneWidget);
    expect(find.textContaining('인터넷 연결과 슬라이드 이미지'), findsOneWidget);
    expect(find.textContaining('TECHNICAL_PRIVATE'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
          .onPressed,
      isNull,
    );
    expect(sink.events.single.error, isA<FormatException>());
    expect(sink.events.single.context['action'], 'workout.preflight.images');
    expect(tester.takeException(), isNull);
  });
  testWidgets('이미지 프리로드는 첫 프레임 이후 안전하게 시작한다', (tester) async {
    final workout =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'user',
            displayName: 'Tester',
            photoUrl: null,
          ),
        ).copyWith(
          name: '테스트 운동',
          modules: [
            WorkoutModule.empty('module').copyWith(
              name: '스쿼트',
              imageSource:
                  'data:image/png;base64,${base64Encode(_onePixelPng)}',
            ),
          ],
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutPreferencesRepositoryProvider.overrideWith(
            (_) => _Preferences(),
          ),
          displayDevicesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: WorkoutPreflightDialog(workout: workout),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('온라인 디스플레이 여러 대를 기본으로 모두 선택한다', (tester) async {
    final workout =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'user',
            displayName: 'Tester',
            photoUrl: null,
          ),
        ).copyWith(
          name: '테스트 운동',
          modules: [WorkoutModule.empty('module').copyWith(name: '스쿼트')],
        );
    final devices = [
      DisplayDevice(
        id: 'display-a',
        name: '메인 TV',
        zoneId: 'main',
        zoneName: '메인 구역',
        online: true,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        currentSessionId: null,
        acknowledgedRevision: 0,
        paired: true,
      ),
      DisplayDevice(
        id: 'display-b',
        name: '보조 TV',
        zoneId: 'main',
        zoneName: '메인 구역',
        online: true,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        currentSessionId: null,
        acknowledgedRevision: 0,
        paired: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutPreferencesRepositoryProvider.overrideWith(
            (_) => _Preferences(),
          ),
          displayDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: WorkoutPreflightDialog(workout: workout),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkboxes = tester.widgetList<CheckboxListTile>(
      find.byWidgetPredicate(
        (w) =>
            w is CheckboxListTile &&
            (w.title is Text) &&
            ['메인 TV', '보조 TV'].contains((w.title as Text).data),
      ),
    );
    expect(checkboxes.length, 2);
    expect(checkboxes.every((tile) => tile.value == true), isTrue);
    expect(find.text('2대를 선택했습니다.'), findsOneWidget);

    await tester.ensureVisible(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pump();
    expect(find.text('브리핑 미리보기'), findsNothing);
    expect(find.text('소리 테스트'), findsNothing);
    expect(find.text('1대를 선택했습니다.'), findsOneWidget);
    expect(
      tester
          .widgetList<CheckboxListTile>(
            find.byWidgetPredicate(
              (w) =>
                  w is CheckboxListTile &&
                  (w.title is Text) &&
                  ['메인 TV', '보조 TV'].contains((w.title as Text).data),
            ),
          )
          .map((tile) => tile.value),
      [true, false],
    );
  });
}

class _PreflightDiagnostics implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async => events.add(event);
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _PreparationRepository implements DisplayPreparationRepository {
  DisplayPreparation? value;
  bool failRequest = false;
  @override
  Future<void> request(DisplayPreparation request) async {
    if (failRequest) throw StateError('PRIVATE_REQUEST_ERROR');
    value = request;
  }

  @override
  Future<void> cancel(String sessionId) async {}
  @override
  Stream<DisplayPreparation?> watchRequest(String deviceId) =>
      Stream.value(value);
  @override
  Future<DisplayPreparation?> current() async => value;
  @override
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() =>
      Stream.value({
        for (final id in value!.targetDeviceIds)
          id: DisplayPreparationReceipt(
            sessionId: value!.sessionId,
            revision: value!.revision,
            manifestHash: value!.manifestHash,
            checkedAtMs: DateTime.now().millisecondsSinceEpoch,
            status: id == 'a' ? 'ready' : 'failed',
            imageCount: value!.images.length,
            audioReady: id == 'a',
          ),
      });
  @override
  Future<Map<String, DisplayPreparationReceipt>> receipts() =>
      watchReceipts().first;
  @override
  Future<void> respond(
    String deviceId,
    DisplayPreparation request, {
    required bool ready,
    required int imageCount,
    required bool audioReady,
  }) async {}
  @override
  Future<void> heartbeat(String deviceId, {bool ready = false}) async {}
  @override
  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
  }) async {}
}

class _Preferences extends Fake implements WorkoutPreferencesRepository {
  WorkoutPreferences? value;
  Object? error;
  Completer<void>? pending;
  int freshReads = 0;
  @override
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) async {
    expect(fresh, isTrue);
    freshReads++;
    await pending?.future;
    if (error != null) throw error!;
    return value;
  }
}

class _Devices extends Fake implements DevicePairingRepository {
  _Devices(this.devices);
  final List<DisplayDevice> devices;
  @override
  Stream<List<DisplayDevice>> watchDevices() => Stream.value(devices);
}
