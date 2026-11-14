import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/main_navigation_dock.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_preparation_actions.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

import 'support/main_navigation_fixture.dart';
import 'support/preparation_fixture.dart';

final workout = navigationWorkouts(
  imageSource: 'http://127.0.0.1:8798/fixture-image.png',
).first;
Finder get startButton => find.byKey(const ValueKey('preparation-start'));
bool enabled(WidgetTester tester) =>
    tester.widget<shadcn.ShadButton>(startButton).onPressed != null;

Future<void> mount(
  WidgetTester tester,
  PreparationFixture fixture, {
  void Function(WorkoutPreflightSelection?)? onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: fixture.overrides,
      child: MaterialApp(
        theme: XonTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await showWorkoutPreflight(context, workout);
                onResult?.call(result);
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
  addTearDown(fixture.dispose);
}

void main() {
  testWidgets(
    'all eligible displays prepare once; every selection edit stays local',
    (tester) async {
      final fixture = PreparationFixture();
      await mount(tester, fixture);
      expect(fixture.repository.requests, 1);
      expect(fixture.source.checks, 1);
      expect(fixture.repository.value!.targetDeviceIds, [
        'tv-0',
        'tv-1',
        'tv-2',
      ]);
      final candidate = fixture.repository.value;
      for (final id in ['tv-0', 'tv-1', 'tv-0', 'tv-1']) {
        await tester.ensureVisible(
          find.byKey(ValueKey('preparation-device-$id')),
        );
        await tester.tap(find.byKey(ValueKey('preparation-device-$id')));
        await tester.pumpAndSettle();
        expect(enabled(tester), isTrue);
        expect(fixture.repository.value, same(candidate));
      }
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(find.text('전체 해제'));
        await tester.tap(find.text('전체 해제'));
        await tester.pumpAndSettle();
        expect(enabled(tester), isFalse);
        expect(find.text('재생할 TV를 선택해 주세요.'), findsOneWidget);
        await tester.tap(find.text('전체 선택'));
        await tester.pumpAndSettle();
        expect(enabled(tester), isTrue);
      }
      await tester.pump(const Duration(seconds: 10));
      expect(fixture.repository.requests, 1);
      expect(fixture.source.checks, 1);
      expect(fixture.deviceSubscriptions, 1);
      expect(find.text('선택 적용'), findsNothing);
      expect(find.text('이 기기에서 재생'), findsNothing);
      expect(find.text('TV에서 재생'), findsNothing);
      expect(find.text('이미지 보기'), findsNothing);
      expect(find.byType(WorkoutSlidePreview), findsNothing);
    },
  );

  testWidgets(
    'unselected failed/offline TVs do not block ready subset or change its proof',
    (tester) async {
      final fixture = PreparationFixture(scene: 'mixed');
      WorkoutPreflightSelection? result;
      var returns = 0;
      await mount(
        tester,
        fixture,
        onResult: (value) {
          result = value;
          returns++;
        },
      );
      final candidate = fixture.repository.value!;
      expect(candidate.targetDeviceIds, ['tv-0', 'tv-1', 'tv-2']);
      expect(enabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('preparation-device-tv-1')));
      await tester.pumpAndSettle();
      expect(enabled(tester), isTrue);
      expect(fixture.repository.requests, 1);
      final press = tester.widget<shadcn.ShadButton>(startButton).onPressed!;
      press();
      press();
      await tester.pumpAndSettle();
      expect(returns, 1);
      expect(result!.targetDeviceIds, ['tv-0']);
      expect(result!.localOnly, isFalse);
      expect(
        result!.preparation!.preparedTargetDeviceIds,
        candidate.targetDeviceIds,
      );
      expect(
        result!.preparation!.clientFingerprint,
        preparationFingerprint(workout, candidate.targetDeviceIds),
      );
      await DisplayPreparationActions(
        fixture.repository,
        _Devices(fixture.devices),
      ).verifyStart(
        workout,
        result!.targetDeviceIds,
        result!.preparation,
        nowMs: fixture.now,
      );
    },
  );

  for (final scene in ['ready', 'offline', 'empty', 'error']) {
    testWidgets(
      'cold $scene preparation and text composition make zero controller HTTP requests',
      (tester) async {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        final fixture = PreparationFixture(
          scene: scene,
          count: scene == 'empty' ? 0 : 3,
        );
        var clients = 0;
        await HttpOverrides.runZoned(
          () async {
            await mount(tester, fixture);
            await tester.drag(
              find.byKey(const ValueKey('preparation-page-scroll')),
              const Offset(0, -800),
            );
            await tester.pumpAndSettle();
            expect(find.text('수업 구성'), findsOneWidget);
            expect(find.byType(WorkoutSlidePreview), findsNothing);
            expect(find.text('이미지 보기'), findsNothing);
            expect(enabled(tester), scene == 'ready');
            if (scene == 'ready') {
              await tester.ensureVisible(find.text('전체 해제'));
              await tester.tap(find.text('전체 해제'));
              await tester.pumpAndSettle();
              expect(enabled(tester), isFalse);
            }
            expect(fixture.repository.requests, scene == 'empty' ? 0 : 1);
          },
          createHttpClient: (_) {
            clients++;
            throw StateError('unexpected controller GET');
          },
        );
        expect(clients, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'initial failure is safe; explicit retry prepares the cohort once',
    (tester) async {
      final fixture = PreparationFixture()..repository.failRequest = true;
      await mount(tester, fixture);
      expect(enabled(tester), isFalse);
      expect(find.textContaining('PRIVATE'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('preparation-device-tv-1')));
      await tester.pumpAndSettle();
      expect(fixture.repository.requests, 1);
      fixture.repository.failRequest = false;
      await tester.ensureVisible(find.text('수업 상태 다시 확인'));
      await tester.tap(find.text('수업 상태 다시 확인'));
      await tester.pumpAndSettle();
      expect(fixture.repository.requests, 2);
      expect(fixture.repository.value!.targetDeviceIds, [
        'tv-0',
        'tv-1',
        'tv-2',
      ]);
      expect(enabled(tester), isTrue);
    },
  );

  for (final reason in [
    'daily_transfer_limit',
    'entitlement_unverified',
    'admission_expired',
    'media_lease_invalid',
  ]) {
    testWidgets('access refusal $reason still blocks start', (tester) async {
      final fixture = PreparationFixture()
        ..source.error = ImageUsageFailure(reason);
      await mount(tester, fixture);
      expect(enabled(tester), isFalse);
      expect(find.text('이용 상태를 다시 확인해 주세요'), findsOneWidget);
      expect(fixture.repository.requests, 0);
    });
  }

  testWidgets(
    'expiry and missing current owner device cannot reuse readiness',
    (tester) async {
      final fixture = PreparationFixture();
      await mount(tester, fixture);
      expect(enabled(tester), isTrue);
      fixture.health.add(fixture.repository.value!.expiresAtMs);
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse);
      expect(fixture.repository.requests, 1);
      fixture.deviceChanges.add([]);
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse);
      expect(fixture.repository.requests, 1);
    },
  );

  testWidgets(
    'account source replacement removes prior readiness and checks again',
    (tester) async {
      final fixture = PreparationFixture();
      await mount(tester, fixture);
      final context = tester.element(find.byType(WorkoutPreparationPage));
      final container = ProviderScope.containerOf(context);
      fixture.repository.scene = 'waiting';
      fixture.source = FixtureUsageSource();
      container.updateOverrides(fixture.overrides);
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse);
      expect(fixture.repository.requests, 2);
    },
  );

  testWidgets(
    'fresh effective preferences stay bound to the preparation proof',
    (tester) async {
      final fixture = PreparationFixture(count: 1);
      final defaults = WorkoutPreferences.fromWorkout(workout);
      fixture.preferences.value = defaults.copyWith(soundVolume: 0);
      WorkoutPreflightSelection? result;
      await mount(tester, fixture, onResult: (value) => result = value);
      await tester.tap(startButton);
      await tester.pumpAndSettle();
      final verify = DisplayPreparationActions(
        fixture.repository,
        _Devices(fixture.devices),
      );
      final effective = await WorkoutPreferencesActions(fixture.preferences)
          .apply(workout, fresh: true);
      await verify.verifyStart(
        effective,
        result!.targetDeviceIds,
        result!.preparation,
        nowMs: fixture.now,
      );
      await expectLater(
        verify.verifyStart(
          workout,
          result!.targetDeviceIds,
          result!.preparation,
          nowMs: fixture.now,
        ),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'settings failure retains readable retry and blocks preparation',
    (tester) async {
      final fixture = PreparationFixture()
        ..preferences.error = StateError('PRIVATE_SETTINGS');
      await mount(tester, fixture);
      expect(find.text('수업 설정을 확인하지 못했어요'), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(enabled(tester), isFalse);
      expect(fixture.repository.requests, 0);
      fixture.preferences.error = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(fixture.preferences.freshReads, 2);
      expect(fixture.repository.requests, 1);
      expect(enabled(tester), isTrue);
    },
  );

  testWidgets(
    'loading preferences shows metadata; back cancels without late prepare',
    (tester) async {
      final fixture = PreparationFixture()
        ..preferences.gate = Completer<void>();
      WorkoutPreflightSelection? result;
      await mount(tester, fixture, onResult: (value) => result = value);
      expect(find.text('수업 구성'), findsOneWidget);
      expect(enabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('preparation-back')));
      await tester.pumpAndSettle();
      fixture.preferences.gate!.complete();
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(fixture.repository.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final spec in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 2.0),
  ]) {
    testWidgets(
      'actual list caller covers shell; back restores list and pinned safe CTA $spec',
      (tester) async {
        tester.view.physicalSize = spec.$1;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock'),
          (_) async => null,
        );
        final fixture = PreparationFixture();
        final data = NavigationPreviewData(
          active: false,
          count: 12,
          preparationOverrides: fixture.overrides,
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: data.container,
              child: MainNavigationPreview(textScale: spec.$2),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(MainNavigationDock), findsOneWidget);
          await tester.tap(find.byTooltip('검색'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'HYROX');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final list = tester.element(
            find.byKey(const ValueKey('workout-scroll')),
          );
          final scroll = tester
              .widget<CustomScrollView>(
                find.byKey(const ValueKey('workout-scroll')),
              )
              .controller!;
          await tester.ensureVisible(find.byTooltip('재생').first);
          await tester.pumpAndSettle();
          final offset = scroll.offset;
          await tester.tap(find.byTooltip('재생').first);
          await tester.pumpAndSettle();
          expect(find.byType(WorkoutPreparationPage), findsOneWidget);
          expect(find.byType(MainNavigationDock), findsNothing);
          expect(
            find.byType(MainNavigationDock, skipOffstage: false),
            findsOneWidget,
          );
          expect(find.text('취소'), findsNothing);
          final rect = tester.getRect(startButton);
          expect(rect.bottom, lessThanOrEqualTo(spec.$1.height - 34));
          expect(rect.top, greaterThan(0));
          await tester.drag(
            find.byKey(const ValueKey('preparation-page-scroll')),
            const Offset(0, -1600),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(startButton), rect);
          expect(find.text('수업 구성').hitTestable(), findsOneWidget);
          expect(startButton.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('preparation-back')));
          await tester.pumpAndSettle();
          expect(find.byType(MainNavigationDock), findsOneWidget);
          expect(
            tester.element(find.byKey(const ValueKey('workout-scroll'))),
            same(list),
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'HYROX',
          );
          expect(scroll.offset, offset);
          expect(
            shadcn.ShadTheme.maybeOf(
              tester.element(find.byType(MainNavigationDock)),
            ),
            isNull,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          data.dispose();
          fixture.dispose();
          await tester.pump();
        }
      },
    );
  }
}

class _Devices implements DevicePairingRepository {
  _Devices(this.devices);
  final List<DisplayDevice> devices;
  @override
  Stream<List<DisplayDevice>> watchDevices() => Stream.value(devices);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
