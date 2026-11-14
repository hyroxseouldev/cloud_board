import 'support/ui_layout_evidence.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';

import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:firebase_core/firebase_core.dart';

import 'support/legacy_image_usage_fixture.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';

import 'dart:async';
import 'dart:io';

import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

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
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets(
    'TV edits stay local until one guarded apply and reuse the device subscription',
    (tester) async {
      final repository = _PreparationRepository()..allReady = true;
      final source = _LegacySource();
      final scope = ValueNotifier<ImageUsageDataSource>(source);
      addTearDown(scope.dispose);
      var subscriptions = 0;
      var images = 0;
      await _previewHarness(
        tester,
        repository,
        (context, sources, {isCancelled}) async {
          images++;
          return 1;
        },
        scope: scope,
        deviceCount: 3,
        onDeviceWatch: () => subscriptions++,
      );
      expect(repository.requests, 1);
      expect(source.checks, 1);
      expect(subscriptions, 1);
      final first = repository.value;
      for (final index in [0, 1, 0, 1]) {
        await tester.tap(find.byType(CheckboxListTile).at(index));
        await tester.pumpAndSettle();
        expect(repository.value, same(first));
        expect(repository.requests, 1);
        expect(source.checks, 1);
        expect(_startEnabled(tester), isFalse);
      }
      await tester.tap(find.text('전체 해제'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '선택 적용'))
            .onPressed,
        isNull,
      );
      expect(_startEnabled(tester), isFalse);
      await tester.tap(find.text('전체 선택'));
      await tester.pumpAndSettle();
      expect(repository.requests, 1);
      final apply = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '선택 적용'))
          .onPressed!;
      apply();
      apply();
      await tester.pumpAndSettle();
      expect(repository.requests, 2);
      expect(source.checks, 2);
      expect(repository.value!.targetDeviceIds.toSet(), {'a', 'b', 'c'});
      expect(subscriptions, 1);
      expect(images, 0);
      expect(_startEnabled(tester), isTrue);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).bottomNavigationBar,
        isNull,
      );
      expect(
        tester.getTopLeft(find.text('수업 시작')).dy,
        lessThan(tester.getTopLeft(find.text('수업 구성')).dy),
      );
    },
  );

  for (final noDevices in [true, false]) {
    testWidgets(
      'explicit solo preserves empty-target routing contract, noDevices=$noDevices',
      (tester) async {
        WorkoutPreflightSelection? selection;
        await _previewHarness(
          tester,
          _PreparationRepository(),
          (context, sources, {isCancelled}) async => 3,
          noDevices: noDevices,
          onSelection: (value) => selection = value,
        );
        await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
        await _applySelection(tester);
        await tester.pumpAndSettle();
        expect(_startEnabled(tester), isTrue);
        await tester.ensureVisible(find.widgetWithText(FilledButton, '수업 시작'));
        await tester.tap(find.widgetWithText(FilledButton, '수업 시작'));
        await tester.pumpAndSettle();
        expect(selection, isNotNull);
        expect(selection!.targetDeviceIds, isEmpty);
        expect(selection!.localOnly, !noDevices);
        expect(selection!.preparation, isNull);
      },
    );
  }

  for (final scenario in ['no devices', 'all offline', 'clear selection']) {
    testWidgets(
      'cold TV intent with $scenario never requests images or empty approval',
      (tester) async {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        var clients = 0;
        final source = _LegacySource();
        final scope = ValueNotifier<ImageUsageDataSource>(source);
        addTearDown(scope.dispose);
        final repository = _PreparationRepository();
        await HttpOverrides.runZoned(
          () async {
            await _previewHarness(
              tester,
              repository,
              null,
              scope: scope,
              noDevices: scenario == 'no devices',
              offline: scenario == 'all offline',
            );
            if (scenario == 'clear selection') {
              await tester.tap(find.text('전체 해제'));
              await tester.pumpAndSettle();
            }
            final checks = source.checks;
            final requests = repository.requests;
            await tester.pump(const Duration(seconds: 10));
            await tester.pumpAndSettle();
            expect(source.checks, checks);
            expect(checks, scenario == 'clear selection' ? 1 : 0);
            expect(repository.requests, requests);
            expect(_startEnabled(tester), isFalse);
            expect(find.textContaining('재생할 TV를 선택해 주세요'), findsOneWidget);
            expect(find.text('시작 이미지 준비 중'), findsNothing);
            expect(find.byType(WorkoutSlidePreview), findsNothing);
          },
          createHttpClient: (_) {
            clients++;
            throw StateError('unexpected automatic HTTP');
          },
        );
        expect(clients, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'explicit solo to TV zero cancels old images and requires new approval on return',
    (tester) async {
      final attempts = <Completer<int>>[];
      final cancelled = <bool Function()?>[];
      final source = _LegacySource();
      final scope = ValueNotifier<ImageUsageDataSource>(source);
      addTearDown(scope.dispose);
      await _previewHarness(
        tester,
        _PreparationRepository(),
        (context, sources, {isCancelled}) {
          cancelled.add(isCancelled);
          final next = Completer<int>();
          attempts.add(next);
          return next.future;
        },
        noDevices: true,
        scope: scope,
      );
      expect(attempts, isEmpty);
      await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(attempts, hasLength(1));
      expect(source.checks, 1);
      expect(_startEnabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('playback-mode-tv')));
      await tester.pumpAndSettle();
      expect(cancelled.first!(), isTrue);
      attempts.first.complete(3);
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isFalse);
      expect(source.checks, 1);
      await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(source.checks, 2);
      expect(attempts, hasLength(2));
      expect(_startEnabled(tester), isFalse);
      attempts.last.complete(3);
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isTrue);
    },
  );

  testWidgets(
    'explicit solo still requires enrolled admission before image preparation',
    (tester) async {
      final source = _AdmissionDeniedSource();
      final scope = ValueNotifier<ImageUsageDataSource>(source);
      addTearDown(scope.dispose);
      var calls = 0;
      await _previewHarness(
        tester,
        _PreparationRepository(),
        (context, sources, {isCancelled}) async {
          calls++;
          return 1;
        },
        noDevices: true,
        scope: scope,
      );
      expect(source.prepares, 0);
      await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(source.prepares, 1);
      expect(source.targets, isEmpty);
      expect(calls, 0);
      expect(_startEnabled(tester), isFalse);
      expect(find.text('이용 상태를 다시 확인해 주세요'), findsOneWidget);
    },
  );

  testWidgets(
    'preparation pushes a page, shows metadata during settings load and back cancels',
    (tester) async {
      final preferences = _Preferences()..pending = Completer<void>();
      final repository = _PreparationRepository();
      final workout =
          Workout.empty(
            'page',
            const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
          ).copyWith(
            name: '페이지 수업',
            modules: [WorkoutModule.empty('m').copyWith(name: '첫 운동')],
          );
      Future<WorkoutPreflightSelection?>? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            legacyImageUsageFixture,
            workoutPreferencesRepositoryProvider.overrideWithValue(preferences),
            displayPreparationRepositoryProvider.overrideWithValue(repository),
            displayDevicesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    result = showWorkoutPreflight(context, workout);
                  },
                  child: const Text('준비 열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('준비 열기'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutPreparationPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        ModalRoute.of(tester.element(find.byType(WorkoutPreparationPage)))!
            .settings
            .name,
        '/workouts/page/prepare',
      );
      expect(find.text('페이지 수업'), findsOneWidget);
      expect(find.text('첫 운동'), findsOneWidget);
      expect(find.byType(WorkoutSlidePreview), findsNothing);
      expect(_startEnabled(tester), isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(await result, isNull);
      preferences.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutPreparationPage), findsNothing);
      expect(repository.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'page image preview is explicit, resets with targets and never repeats TV preparation',
    (tester) async {
      final repository = _PreparationRepository();
      var calls = 0;
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) async {
        calls++;
        return 1;
      });
      expect(find.text('수업 구성'), findsOneWidget);
      expect(find.byType(WorkoutSlidePreview), findsNothing);
      expect(calls, 0);
      await tester.ensureVisible(find.text('이미지 보기'));
      await tester.tap(find.text('이미지 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutSlidePreview), findsOneWidget);
      expect(
        _startEnabled(tester),
        isTrue,
        reason: 'optional display failure cannot gate remote start',
      );
      expect(repository.requests, 1);
      expect(calls, 0);
      await tester.ensureVisible(find.text('전체 해제'));
      await tester.tap(find.text('전체 해제'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutSlidePreview), findsNothing);
      expect(
        calls,
        0,
        reason: 'clearing TVs must not opt into solo image preparation',
      );
      await tester.ensureVisible(find.text('전체 선택'));
      await tester.tap(find.text('전체 선택'));
      await tester.pumpAndSettle();
      expect(repository.requests, 1);
      expect(_startEnabled(tester), isFalse);
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutSlidePreview), findsNothing);
      expect(repository.requests, 2);
      expect(_startEnabled(tester), isTrue);
    },
  );

  testWidgets(
    'cold cache real preflight loader never reaches HTTP for remote mode',
    (tester) async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      var clients = 0;
      await HttpOverrides.runZoned(
        () async {
          await _previewHarness(tester, _PreparationRepository(), null);
          await tester.pump(const Duration(seconds: 6));
          expect(_startEnabled(tester), isTrue);
          expect(find.text('시작 이미지 준비 중'), findsNothing);
          expect(find.textContaining('미리보기'), findsNothing);
        },
        createHttpClient: (context) {
          clients++;
          throw StateError('unexpected HTTP');
        },
      );
      expect(clients, 0);
      expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled solo loader cannot schedule remaining image window', (
    tester,
  ) async {
    final first = Completer<void>();
    final loaded = <String>[];
    await _previewHarness(
      tester,
      _PreparationRepository(),
      (context, sources, {isCancelled}) => warmWorkoutImages(
        sources,
        concurrency: 1,
        isCancelled: isCancelled,
        load: (source) async {
          loaded.add(source);
          await first.future;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
    await _applySelection(tester);
    await tester.pumpAndSettle();
    expect(loaded, hasLength(1));
    expect(loaded.single, contains('countdown'));
    await tester.tap(find.byKey(const ValueKey('playback-mode-tv')));
    await _applySelection(tester);
    await tester.pumpAndSettle();
    first.complete();
    await tester.pumpAndSettle();
    expect(loaded, hasLength(1));
    expect(_startEnabled(tester), isTrue);
  });

  testWidgets(
    'remote never calls image loader while waiting, ready, failed or retrying',
    (tester) async {
      final repository = _PreparationRepository()..pendingReceipts = true;
      var calls = 0;
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) async {
        calls++;
        throw StateError('remote must never load');
      }, legacy: true);
      expect(calls, 0);
      expect(_startEnabled(tester), isFalse);
      expect(find.textContaining('이미지 사전 확인 미지원 1대'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('5초 이상'), findsOneWidget);
      await captureLayout(
        tester,
        find.byKey(const ValueKey('preflight-evidence')),
        'remote-waiting',
      );
      repository.failRequest = true;
      await tester.tap(find.text('TV 준비 다시 확인'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(_startEnabled(tester), isFalse);
      expect(find.text('이용 상태를 다시 확인해 주세요'), findsOneWidget);
      await captureLayout(
        tester,
        find.byKey(const ValueKey('preflight-evidence')),
        'remote-error',
      );
      repository.failRequest = false;
      repository.pendingReceipts = false;
      await tester.tap(find.text('수업 상태 다시 확인'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(repository.requests, 3);
      expect(_startEnabled(tester), isTrue);
      expect(find.textContaining('미리보기'), findsNothing);
      expect(find.textContaining('5초 이상'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(
        repository.requests,
        3,
        reason: 'status rebuild must not reprepare TVs',
      );
      await captureLayout(
        tester,
        find.byKey(const ValueKey('preflight-evidence')),
        'remote-ready',
      );
    },
  );

  testWidgets(
    'remote to solo to remote cancels queued images and late success cannot unlock new solo',
    (tester) async {
      final attempts = <Completer<int>>[];
      final cancelled = <bool Function()?>[];
      final repository = _PreparationRepository();
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) {
        final next = Completer<int>();
        attempts.add(next);
        cancelled.add(isCancelled);
        return next.future;
      });
      expect(attempts, isEmpty);
      await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(attempts, hasLength(1));
      expect(_startEnabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('playback-mode-tv')));
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(cancelled.first!(), isTrue);
      expect(attempts, hasLength(1));
      expect(_startEnabled(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(attempts, hasLength(2));
      attempts.first.complete(1);
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isFalse);
      attempts.last.completeError(StateError('decode'));
      await tester.pumpAndSettle();
      expect(find.text('이미지 준비 실패'), findsOneWidget);
      expect(_startEnabled(tester), isFalse);
      await tester.tap(find.text('시작 이미지 다시 불러오기'));
      await tester.pumpAndSettle();
      attempts.last.complete(1);
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), isTrue);
      expect(
        repository.requests,
        2,
        reason: 'solo image retry does not publish TV preparation',
      );
      await captureLayout(
        tester,
        find.byKey(const ValueKey('preflight-evidence')),
        'solo-ready',
      );
    },
  );

  for (final ready in [false, true]) {
    testWidgets('TV gate uses receipt only, ready=$ready', (tester) async {
      final tv = Completer<void>();
      final repository = _PreparationRepository()
        ..receiptGate = tv
        ..pendingReceipts = !ready;
      var calls = 0;
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) async {
        calls++;
        return 1;
      });
      expect(_startEnabled(tester), isFalse);
      tv.complete();
      await tester.pumpAndSettle();
      expect(_startEnabled(tester), ready);
      expect(calls, 0);
    });
  }

  testWidgets('remote never enters managed preview transport path', (
    tester,
  ) async {
    var calls = 0;
    await _previewHarness(tester, _PreparationRepository(), (
      context,
      sources, {
      isCancelled,
    }) async {
      calls++;
      throw const ImageUsageFailure('service_unavailable');
    });
    expect(calls, 0);
    expect(_startEnabled(tester), isTrue);
    expect(find.textContaining('미리보기'), findsNothing);
  });

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('narrow scaled critical error and body CTA reachable $size', (
      tester,
    ) async {
      await _previewHarness(
        tester,
        _PreparationRepository()..failRequest = true,
        (context, sources, {isCancelled}) async =>
            throw StateError('no remote loader'),
        size: size,
        scale: 2.0,
      );
      expect(_startEnabled(tester), isFalse);
      expect(find.text('이용 상태를 다시 확인해 주세요'), findsOneWidget);
      await tester.ensureVisible(find.text('수업 상태 다시 확인'));
      expect(find.text('수업 상태 다시 확인').hitTestable(), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).bottomNavigationBar,
        isNull,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, '수업 시작'));
      expect(
        find.widgetWithText(FilledButton, '수업 시작').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await captureLayout(
        tester,
        find.byKey(const ValueKey('preflight-evidence')),
        'remote-error-${size.width.toInt()}-scaled',
      );
    });
  }

  for (final failure in <Object>[
    const ImageUsageFailure('daily_transfer_limit'),
    const ImageUsageFailure('entitlement_unverified'),
    const ImageUsageFailure('admission_expired'),
    const ImageUsageFailure('media_lease_invalid'),
    FirebaseException(plugin: 'auth', code: 'permission-denied'),
  ]) {
    testWidgets(
      'remote access refusal remains blocking without images: $failure',
      (tester) async {
        var calls = 0;
        final scope = ValueNotifier<ImageUsageDataSource>(
          _DeniedSource(failure),
        );
        addTearDown(scope.dispose);
        await _previewHarness(tester, _PreparationRepository(), (
          context,
          sources, {
          isCancelled,
        }) async {
          calls++;
          return 1;
        }, scope: scope);
        expect(calls, 0);
        expect(_startEnabled(tester), isFalse);
        expect(find.text('이용 상태를 다시 확인해 주세요'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '이미지 보기'))
              .onPressed,
          isNull,
        );
        expect(find.textContaining('미리보기'), findsNothing);
      },
    );
  }

  testWidgets(
    'account scope change invalidates preparation without starting images',
    (tester) async {
      final repository = _PreparationRepository();
      var calls = 0;
      final scope = ValueNotifier<ImageUsageDataSource>(_LegacySource());
      addTearDown(scope.dispose);
      await _previewHarness(tester, repository, (
        context,
        sources, {
        isCancelled,
      }) async {
        calls++;
        return 1;
      }, scope: scope);
      final previous = repository.value!.sessionId;
      repository.pendingReceipts = true;
      scope.value = _LegacySource();
      await tester.pumpAndSettle();
      expect(repository.requests, 2);
      expect(repository.value!.sessionId, isNot(previous));
      expect(_startEnabled(tester), isFalse);
      expect(calls, 0);
    },
  );

  testWidgets('unresolved account hides old readiness without images', (
    tester,
  ) async {
    var calls = 0;
    final scope = ValueNotifier<ImageUsageDataSource>(_LegacySource());
    addTearDown(scope.dispose);
    await _previewHarness(tester, _PreparationRepository(), (
      context,
      sources, {
      isCancelled,
    }) async {
      calls++;
      return 1;
    }, scope: scope);
    expect(_startEnabled(tester), isTrue);
    scope.value = _UnavailableSource();
    await tester.pumpAndSettle();
    expect(find.textContaining('계정 연결을 확인하지 못했어요'), findsOneWidget);
    expect(find.textContaining('PRIVATE_ACCOUNT'), findsNothing);
    expect(_startEnabled(tester), isFalse);
    expect(calls, 0);
  });

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
          child: MaterialApp(home: WorkoutPreparationPage(workout: raw)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('수업 설정을 확인하지 못했어요'), findsOneWidget);
      expect(find.textContaining('PRIVATE_SETTINGS_ERROR'), findsNothing);
      expect(_startEnabled(tester), isFalse);
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
          child: MaterialApp(home: WorkoutPreparationPage(workout: raw)),
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
          home: WorkoutPreparationPage(workout: workout),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('TV 준비 요청을 보내지 못했어요.'), findsOneWidget);
    expect(
      find.textContaining('준비되지 않은 TV는 선택을 해제해 제외할 수 있어요.'),
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
    await tester.tap(find.text('수업 상태 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('TV 이미지 준비 1/1대 완료'), findsOneWidget);
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
      expect(find.text('TV 이미지 준비 1/2대 완료'), findsOneWidget);
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
      expect(repository.value!.targetDeviceIds, ['a', 'b']);
      expect(_startEnabled(tester), isFalse);
      await _applySelection(tester);
      await tester.pumpAndSettle();
      expect(repository.value!.targetDeviceIds, ['a']);
      expect(repository.value!.manifestHash, isNot(both));
      expect(find.text('TV 이미지 준비 1/1대 완료'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, '수업 시작'));
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
          home: WorkoutPreparationPage(workout: workout),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
    await _applySelection(tester);
    await tester.pumpAndSettle();
    expect(find.text('이미지 준비 실패'), findsOneWidget);
    expect(find.textContaining('연결을 확인해 주세요'), findsOneWidget);
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
          home: WorkoutPreparationPage(workout: workout),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('playback-mode-solo')));
    await _applySelection(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('이미지 준비 완료'), findsOneWidget);

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
          home: WorkoutPreparationPage(workout: workout),
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
    expect(find.text('재생 TV · 2대 선택'), findsOneWidget);

    await tester.ensureVisible(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pump();
    expect(find.text('브리핑 미리보기'), findsNothing);
    expect(find.text('소리 테스트'), findsNothing);
    expect(find.text('재생 TV · 1대 선택'), findsOneWidget);
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
  bool allReady = false;
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
          status: allReady || id == 'a'
              ? (pendingReceipts ? 'preparing' : 'ready')
              : 'failed',
          imageCount: value!.images.length,
          audioReady: allReady || id == 'a',
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

Future<void> _applySelection(WidgetTester tester) async {
  await tester.pump();
  final apply = find.widgetWithText(FilledButton, '선택 적용');
  await tester.ensureVisible(apply);
  await tester.tap(apply);
  await tester.pump();
}

bool _startEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
        .onPressed !=
    null;

Future<void> _previewHarness(
  WidgetTester tester,
  _PreparationRepository repository,
  PreflightImageLoader? loader, {
  bool legacy = false,
  bool noDevices = false,
  bool offline = false,
  int deviceCount = 1,
  VoidCallback? onDeviceWatch,
  void Function(WorkoutPreflightSelection?)? onSelection,
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
    if (!noDevices)
      for (final id in [
        'a',
        if (deviceCount > 1) 'b',
        if (deviceCount > 2) 'c',
        if (legacy) 'old',
      ])
        DisplayDevice(
          id: id,
          name: 'TV $id',
          zoneId: 'main',
          zoneName: '',
          online: !offline,
          lastSeenAtMs: offline ? 0 : DateTime.now().millisecondsSinceEpoch,
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
        countdownImageSource: 'http://127.0.0.1:8796/countdown-test.png',
        modules: [
          for (var i = 0; i < 4; i++)
            WorkoutModule.empty('m$i').copyWith(
              name: '스쿼트',
              imageSource: 'http://127.0.0.1:8796/slide-$i.png',
            ),
        ],
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
        displayDevicesProvider.overrideWith((_) {
          onDeviceWatch?.call();
          return Stream.value(devices);
        }),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        deviceIdProvider.overrideWith((_) async => 'local-test-controller'),
        displayPreparationRepositoryProvider.overrideWithValue(repository),
        if (loader != null)
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
        home: onSelection == null
            ? RepaintBoundary(
                key: const ValueKey('preflight-evidence'),
                child: WorkoutPreparationPage(workout: workout),
              )
            : Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async => onSelection(
                      await showWorkoutPreflight(context, workout),
                    ),
                    child: const Text('준비 열기'),
                  ),
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (onSelection != null) {
    await tester.tap(find.text('준비 열기'));
    await tester.pumpAndSettle();
  }
}

class _LegacySource extends Fake implements ImageUsageDataSource {
  int checks = 0;
  @override
  Future<bool> enrolled() async {
    checks++;
    return false;
  }
}

class _UnavailableSource extends Fake implements ImageUsageDataSource {}

class _DeniedSource extends _LegacySource {
  _DeniedSource(this.failure);
  final Object failure;
  @override
  Future<bool> enrolled() async => throw failure;
}

class _AdmissionDeniedSource extends _LegacySource {
  int prepares = 0;
  List<String>? targets;
  @override
  Future<bool> enrolled() async => true;
  @override
  Future<ClassAdmission> prepare({
    required Map<String, dynamic> workout,
    required List<String> targets,
    required String controllerDeviceId,
    required String clientFingerprint,
  }) async {
    prepares++;
    this.targets = targets;
    throw const ImageUsageFailure('daily_transfer_limit');
  }
}
