import 'support/ui_layout_evidence.dart';

import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:firebase_core/firebase_core.dart';

import 'support/legacy_image_usage_fixture.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';

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
  testWidgets(
    'slow remote preview is auxiliary; retry never prepares TVs or starts a class',
    (tester) async {
      final repository = _PreparationRepository();
      final attempts = <Completer<int>>[];
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) {
        final next = Completer<int>();
        attempts.add(next);
        return next.future;
      });
      expect(attempts, hasLength(1));
      expect(_startEnabled(tester), isTrue);
      final candidate = repository.value!;
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('컨트롤러 미리보기 불러오는 중 · 5초 이상'), findsOneWidget);
      expect(_startEnabled(tester), isTrue);
      await captureLayout(
        tester,
        find.byKey(const ValueKey('preflight-evidence')),
        'remote-preview-slow',
      );
      attempts.single.completeError(StateError('PRIVATE_IMAGE_FAILURE'));
      await tester.pumpAndSettle();
      expect(find.text('미리보기를 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('PRIVATE_IMAGE_FAILURE'), findsNothing);
      await captureLayout(
        tester,
        find.byKey(const ValueKey('preflight-evidence')),
        'remote-preview-error',
      );
      expect(_startEnabled(tester), isTrue);
      await tester.ensureVisible(find.text('미리보기 다시 불러오기'));
      await tester.tap(find.text('미리보기 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(attempts, hasLength(2));
      expect(repository.requests, 1);
      expect(repository.value, same(candidate));
      expect(_startEnabled(tester), isTrue);
      attempts.last.complete(1);
      await tester.pumpAndSettle();
      expect(find.text('컨트롤러 미리보기 준비됨'), findsOneWidget);
      expect(repository.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zero targets use solo gate and stale remote preview cannot release it',
    (tester) async {
      final repository = _PreparationRepository();
      final attempts = <Completer<int>>[];
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) {
        final next = Completer<int>();
        attempts.add(next);
        return next.future;
      });
      expect(_startEnabled(tester), isTrue);
      await tester.ensureVisible(find.text('전체 해제'));
      await tester.tap(find.text('전체 해제'));
      await tester.pumpAndSettle();
      expect(attempts, hasLength(2));
      expect(_startEnabled(tester), isFalse);
      attempts.first.complete(1);
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isFalse);
      attempts.last.completeError(StateError('decode'));
      await tester.pumpAndSettle();
      expect(find.text('이미지 준비 실패'), findsOneWidget);
      expect(_startEnabled(tester), isFalse);
      await tester.ensureVisible(find.text('시작 이미지 다시 불러오기'));
      await tester.tap(find.text('시작 이미지 다시 불러오기'));
      await tester.pumpAndSettle();
      attempts.last.complete(1);
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isTrue);
      expect(
        repository.requests,
        1,
        reason: 'solo/preview retries do not publish a TV candidate',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending TV still blocks with ready preview; legacy is not counted ready',
    (tester) async {
      final repository = _PreparationRepository()..pendingReceipts = true;
      await _previewHarness(
        tester,
        repository,
        (context, sources, {isCancelled}) async => 1,
        legacy: true,
      );
      expect(_startEnabled(tester), isFalse);
      expect(find.text('TV 1대 중 0대 준비 완료'), findsOneWidget);
      expect(find.textContaining('이미지 준비 상태 미지원 1대'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.textContaining('대상 TV의 실제 준비 상태 확인 중 · 5초 이상'),
        findsOneWidget,
      );
      repository.pendingReceipts = false;
      await tester.ensureVisible(find.text('TV 준비 다시 확인'));
      await tester.tap(find.text('TV 준비 다시 확인'));
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isTrue);
      expect(find.text('TV 1대 중 1대 준비 완료'), findsOneWidget);
    },
  );

  for (final previewLast in [true, false]) {
    testWidgets('matched fake critical path: previewLast=$previewLast', (
      tester,
    ) async {
      final images = Completer<int>();
      final tv = Completer<void>();
      final repository = _PreparationRepository()..receiptGate = tv;
      await _previewHarness(
        tester,
        repository,
        (context, sources, {isCancelled}) => images.future,
      );
      expect(_startEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 3));
      if (previewLast) {
        tv.complete();
      } else {
        images.complete(1);
      }
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), previewLast);
      await tester.pump(const Duration(seconds: 5));
      if (previewLast) {
        images.complete(1);
      } else {
        tv.complete();
      }
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isTrue);
      // Controlled fake milestones: C=8,V=3 removes 5s of required wait;
      // C=3,V=8 removes 0s. Neither is a field measurement or throughput claim.
    });
  }

  testWidgets('managed preview transport failure stays auxiliary', (
    tester,
  ) async {
    await _previewHarness(
      tester,
      _PreparationRepository(),
      (context, sources, {isCancelled}) async =>
          throw const ImageUsageFailure('service_unavailable'),
    );
    expect(_startEnabled(tester), isTrue);
    expect(find.text('미리보기 다시 불러오기'), findsOneWidget);
  });

  testWidgets('narrow scaled preview keeps start and retry reachable', (
    tester,
  ) async {
    await _previewHarness(
      tester,
      _PreparationRepository(),
      (context, sources, {isCancelled}) async => throw StateError('decode'),
      size: const Size(320, 568),
      scale: 1.3,
    );
    expect(_startEnabled(tester), isTrue);
    await tester.ensureVisible(find.text('미리보기 다시 불러오기'));
    expect(find.text('미리보기 다시 불러오기').hitTestable(), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, '수업 시작').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await captureLayout(
      tester,
      find.byKey(const ValueKey('preflight-evidence')),
      'remote-narrow-scaled',
    );
  });

  for (final failure in <Object>[
    const ImageUsageFailure('daily_transfer_limit'),
    const ImageUsageFailure('entitlement_unverified'),
    const ImageUsageFailure('admission_expired'),
    const ImageUsageFailure('media_lease_invalid'),
    FirebaseException(plugin: 'auth', code: 'permission-denied'),
  ]) {
    testWidgets(
      'approval/lease refusal is not downgraded to preview error: $failure',
      (tester) async {
        await _previewHarness(
          tester,
          _PreparationRepository(),
          (context, sources, {isCancelled}) async => throw failure,
        );
        expect(_startEnabled(tester), isFalse);
        expect(find.text('이용 상태를 다시 확인해 주세요'), findsOneWidget);
        expect(find.text('미리보기 다시 불러오기'), findsNothing);
      },
    );
  }

  testWidgets(
    'account scope change invalidates prior preview and preparation',
    (tester) async {
      final repository = _PreparationRepository();
      final attempts = <Completer<int>>[];
      final scope = ValueNotifier<ImageUsageDataSource>(_LegacySource());
      addTearDown(scope.dispose);
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) {
        final next = Completer<int>();
        attempts.add(next);
        return next.future;
      }, scope: scope);
      final previous = repository.value!.sessionId;
      scope.value = _LegacySource();
      await tester.pumpAndSettle();
      expect(repository.requests, 2);
      expect(repository.value!.sessionId, isNot(previous));
      expect(attempts, hasLength(2));
      attempts.first.completeError(
        const ImageUsageFailure('entitlement_unverified'),
      );
      await tester.pumpAndSettle();
      expect(find.text('이용 상태를 다시 확인해 주세요'), findsNothing);
      expect(_startEnabled(tester), isTrue);
      attempts.last.complete(1);
      await tester.pumpAndSettle();
      expect(find.text('컨트롤러 미리보기 준비됨'), findsOneWidget);
    },
  );

  testWidgets(
    'unresolved account hides old readiness and late preview result',
    (tester) async {
      final image = Completer<int>();
      final scope = ValueNotifier<ImageUsageDataSource>(_LegacySource());
      addTearDown(scope.dispose);
      await _previewHarness(
        tester,
        _PreparationRepository(),
        (context, sources, {isCancelled}) => image.future,
        scope: scope,
      );
      expect(_startEnabled(tester), isTrue);
      scope.value = _UnavailableSource();
      await tester.pumpAndSettle();
      expect(find.textContaining('계정 연결을 확인하지 못했어요'), findsOneWidget);
      expect(find.textContaining('PRIVATE_ACCOUNT'), findsNothing);
      expect(find.text('수업 시작'), findsNothing);
      image.complete(1);
      await tester.pumpAndSettle();
      expect(find.text('수업 시작'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
              legacyImageUsageFixture,
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
            legacyImageUsageFixture,
            displayPreparationRepositoryProvider.overrideWith(
              (_) => _PreparationRepository(),
            ),
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
            legacyImageUsageFixture,
            displayPreparationRepositoryProvider.overrideWith(
              (_) => _PreparationRepository(),
            ),
            workoutPreferencesRepositoryProvider.overrideWith(
              (_) => preferences,
            ),
          ],
          child: MaterialApp(home: WorkoutPreflightDialog(workout: raw)),
        ),
      );
      await tester.pump();
      expect(find.text('최신 수업 설정 확인 중'), findsOneWidget);
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
          legacyImageUsageFixture,
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
            legacyImageUsageFixture,
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
          legacyImageUsageFixture,
          displayPreparationRepositoryProvider.overrideWith(
            (_) => _PreparationRepository(),
          ),
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
          legacyImageUsageFixture,
          displayPreparationRepositoryProvider.overrideWith(
            (_) => _PreparationRepository(),
          ),
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
          legacyImageUsageFixture,
          displayPreparationRepositoryProvider.overrideWith(
            (_) => _PreparationRepository(),
          ),
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
  bool pendingReceipts = false;
  int requests = 0;
  Completer<void>? receiptGate;
  @override
  Future<void> request(DisplayPreparation request) async {
    requests++;
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
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() async* {
    await receiptGate?.future;
    yield {
      for (final id in value!.targetDeviceIds)
        id: DisplayPreparationReceipt(
          sessionId: value!.sessionId,
          revision: value!.revision,
          manifestHash: value!.manifestHash,
          checkedAtMs: DateTime.now().millisecondsSinceEpoch,
          status: id == 'a'
              ? (pendingReceipts ? 'preparing' : 'ready')
              : 'failed',
          imageCount: value!.images.length,
          audioReady: id == 'a',
        ),
    };
  }

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
  Future<void> heartbeat(
    String deviceId, {
    bool ready = false,
    DisplayHeartbeatPolicy? policy,
    String? connectionId,
  }) async {}
  @override
  Future<void> reportHealth(
    String deviceId, {
    String? stage,
    String? code,
    int attempt = 1,
    String? requestId,
    String? connectionId,
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

bool _startEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
        .onPressed !=
    null;

Future<void> _previewHarness(
  WidgetTester tester,
  _PreparationRepository repository,
  PreflightImageLoader loader, {
  bool legacy = false,
  Size size = const Size(600, 1300),
  double scale = 1,
  ValueNotifier<ImageUsageDataSource>? scope,
}) async {
  if (layoutEvidenceDirectory.isNotEmpty) await loadLayoutFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final devices = [
    for (final id in ['a', if (legacy) 'old'])
      DisplayDevice(
        id: id,
        name: 'TV $id',
        zoneId: 'main',
        zoneName: '',
        online: true,
        lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
        currentSessionId: null,
        acknowledgedRevision: 0,
        paired: true,
        playbackProtocol: 5,
        preparationProtocol: id == 'old' ? 0 : 1,
      ),
  ];
  final workout =
      Workout.empty(
        'preview',
        const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
      ).copyWith(
        name: '로컬 준비 테스트',
        modules: [WorkoutModule.empty('m').copyWith(name: '스쿼트')],
      );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (scope == null)
          legacyImageUsageFixture
        else
          imageUsageSourceProvider.overrideWith((ref) {
            void changed() => ref.invalidateSelf();
            scope.addListener(changed);
            ref.onDispose(() => scope.removeListener(changed));
            if (scope.value is _UnavailableSource) {
              throw StateError('PRIVATE_ACCOUNT');
            }
            return scope.value;
          }),
        workoutPreferencesRepositoryProvider.overrideWith(
          (_) => _Preferences(),
        ),
        displayDevicesProvider.overrideWith((_) => Stream.value(devices)),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        displayPreparationRepositoryProvider.overrideWithValue(repository),
        preflightImageLoaderProvider.overrideWithValue(loader),
      ],
      child: MaterialApp(
        theme: XonTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('preflight-evidence'),
          child: WorkoutPreflightDialog(workout: workout),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _LegacySource extends Fake implements ImageUsageDataSource {
  @override
  Future<bool> enrolled() async => false;
}

class _UnavailableSource extends Fake implements ImageUsageDataSource {}
