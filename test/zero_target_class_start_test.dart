import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

import 'support/playback_image_cache_fixture.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/main_navigation_dock.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';

import 'support/main_navigation_fixture.dart';
import 'support/preparation_fixture.dart';
import 'support/ui_layout_evidence.dart';
import 'workout_preflight_dialog_test.dart' show enabled, startButton, mount;

// Production app router/list/preparation/player/controllers. Only external
// repositories and platform channels are fake; no Firebase SDK connection.
void main() {
  for (final count in [0, 2]) {
    testWidgets(
      'real router starts and controls with $count registered / zero selected TVs',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
        final fixture = PreparationFixture(count: count);
        final playback = _NoRemoteWrites();
        var now = DateTime.now();
        final data = NavigationPreviewData(
          active:
              true, // Existing remote class must survive local controls/exit.
          imageSource: 'http://127.0.0.1:8798/no-eager-image.png',
          preparationOverrides: [
            ...fixture.overrides,
            beepPlayerProvider.overrideWithValue(_SilentBeep()),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            playbackRepositoryProvider.overrideWithValue(playback),
            playbackActionControllerProvider.overrideWith(
              PlaybackActionController.new,
            ),
            playerClockProvider.overrideWith(
              (ref) =>
                  () => now,
            ),
          ],
        );
        // Existing class uses its own image-free fixture. It must not cause
        // unrelated mini-controller thumbnail requests in the media counter.
        data.setSession(navigationSession(navigationWorkouts().first));
        final existing = data.session;
        data.repository.items[0] = data.repository.items.first.copyWith(
          countdownSeconds: 3,
          countdownImageSource: 'http://127.0.0.1:8798/no-countdown-image.png',
        );
        var disposed = false;
        void disposeData() {
          if (disposed) return;
          disposed = true;
          data.dispose();
        }

        addTearDown(disposeData);
        addTearDown(fixture.dispose);
        final media = PlaybackImageCacheFixture();
        CachedNetworkImageProvider.defaultCacheManager = media;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        addTearDown(() {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        });
        var httpClients = 0;
        await HttpOverrides.runZoned(
          () async {
            await loadLayoutFonts(tester);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: data.container,
                child: const RepaintBoundary(
                  key: ValueKey('evidence'),
                  child: MainNavigationPreview(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            httpClients =
                0; // Count preparation/player only; home is unchanged.
            media.requests.clear();
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            await tester.tap(find.byTooltip('재생').first);
            await tester.pumpAndSettle();
            expect(find.byType(MainNavigationDock), findsNothing);
            expect(fixture.source.checks, 1);
            if (count > 0) {
              await tester.tap(find.text('전체 해제'));
              await tester.pumpAndSettle();
              expect(fixture.repository.requests, 1);
              expect(fixture.repository.cancelled, isEmpty); // checkbox RPC0
            } else {
              expect(fixture.repository.requests, 0);
            }
            expect(enabled(tester), isTrue);
            expect(httpClients, 0);
            expect(media.requests, isEmpty); // Preparation remains text-only.
            await captureLayout(
              tester,
              find.byKey(const ValueKey('evidence')),
              'local-fixture-$count-tv-start-enabled',
            );
            final preparedId = fixture.repository.value?.sessionId;
            // Pending cleanup fences double-taps and does not navigate early.
            fixture.source.accessGate = Completer<void>();
            await tester.tap(startButton);
            await tester.pump();
            expect(enabled(tester), isFalse);
            expect(find.byType(WorkoutPlayerScreen), findsNothing);
            await tester.tap(startButton);
            fixture.source.accessGate!.complete();
            await tester.pumpAndSettle();
            final player = tester.widget<WorkoutPlayerScreen>(
              find.byType(WorkoutPlayerScreen),
            );
            expect(player.sessionId, isNull);
            expect(
              GoRouterState.of(tester.element(find.byType(WorkoutPlayerScreen)))
                  .uri
                  .path,
              '/player/preview-0',
            );
            expect(
              fixture.repository.cancelled,
              count == 0 ? isEmpty : [preparedId],
            );
            expect(fixture.repository.value, isNull);
            expect(fixture.source.checks, 2);
            final countdown = tester.widget<WorkoutCountdown>(
              find.byType(WorkoutCountdown),
            );
            expect(
              countdown.workout.countdownImageSource,
              'http://127.0.0.1:8798/no-countdown-image.png',
            );
            expect(find.byType(WorkoutImage), findsOneWidget);
            expect(media.requests, [
              'http://127.0.0.1:8798/no-countdown-image.png',
            ]);
            expect(httpClients, 0); // Fake cache delivery, no external HTTP.
            now = now.add(const Duration(seconds: 4));
            await tester.pump(const Duration(seconds: 4));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pumpAndSettle();
            expect(find.text('미리보기 보기'), findsNothing);
            expect(find.text('미리보기 닫기'), findsNothing);
            expect(find.byType(PageView), findsOneWidget);
            expect(find.byType(WorkoutSlideCanvas), findsWidgets);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await tester.pumpAndSettle();
            expect(media.requests.toSet(), {
              'http://127.0.0.1:8798/no-countdown-image.png',
              'http://127.0.0.1:8798/no-eager-image.png',
            });
            expect(
              tester
                  .widgetList<RawImage>(find.byType(RawImage))
                  .any((image) => image.image != null),
              isTrue,
            );
            final provider = playerControllerProvider(
              data.repository.items.first,
            );
            final before = data.container.read(provider).remainingMs;
            now = now.add(const Duration(seconds: 2));
            await tester.pump(const Duration(seconds: 2));
            expect(data.container.read(provider).remainingMs, lessThan(before));
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await tester.pump();
            expect(data.container.read(provider).isPaused, isTrue);
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await tester.pump();
            expect(data.container.read(provider).isPaused, isFalse);
            await captureLayout(
              tester,
              find.byKey(const ValueKey('evidence')),
              'local-fixture-$count-tv-timer-controls',
            );
            expect(httpClients, 0);
            expect(playback.calls, isEmpty);
            expect(data.session, same(existing));
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(FilledButton, '수업 종료'));
            await tester.pumpAndSettle();
            expect(find.byType(MainNavigationDock), findsOneWidget);
            expect(data.session, same(existing));
            expect(playback.calls, isEmpty);
            expect(data.commands.transports, 0);
            expect(tester.takeException(), isNull);
            // ignore: avoid_print
            print(
              'zero-target counters registered=$count prepare=${fixture.repository.requests} access=${fixture.source.checks} cancel=${fixture.repository.cancelled.length} remoteWrites=${playback.calls.length} externalHTTP=$httpClients fakeMediaLoads=${media.requests.length} activeUnchanged=true',
            );
            await tester.pumpWidget(const SizedBox());
            disposeData();
            await tester.pump();
          },
          createHttpClient: (_) {
            httpClients++;
            throw StateError('unexpected media GET');
          },
        );
      },
    );
  }

  testWidgets('zero TVs cannot start an empty workout', (tester) async {
    final fixture = PreparationFixture(count: 0);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fixture.overrides,
        child: MaterialApp(
          home: WorkoutPreparationPage(
            workout: navigationWorkouts().first.copyWith(modules: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(enabled(tester), isFalse);
    expect(find.text('수업 내용을 확인해 주세요'), findsOneWidget);
    expect(fixture.repository.requests, 0);
  });

  testWidgets(
    'zero TVs waits for access and never converts denial into local start',
    (tester) async {
      final fixture = PreparationFixture(count: 0);
      fixture.source.accessGate = Completer<void>();
      await mount(tester, fixture);
      expect(enabled(tester), isFalse);
      fixture.source.error = const ImageUsageFailure('entitlement_unverified');
      fixture.source.accessGate!.complete();
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse);
      expect(fixture.repository.requests, 0);
      expect(find.text('이용 상태를 다시 확인해 주세요'), findsOneWidget);
    },
  );

  testWidgets('zero TVs preserves denied and unresolved entitlement gates', (
    tester,
  ) async {
    final fixture = PreparationFixture(count: 0);
    final access = StreamController<StoreEntitlement?>();
    addTearDown(access.close);
    final data = NavigationPreviewData(
      active: false,
      preparationOverrides: [
        ...fixture.overrides,
        storeEntitlementProvider.overrideWith((ref) => access.stream),
      ],
    );
    addTearDown(data.dispose);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: data.container,
        child: const MainNavigationPreview(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('재생').first);
    await tester.pumpAndSettle();
    expect(enabled(tester), isFalse);
    access.add(
      StoreEntitlement(
        ownerId: 'navigation-preview',
        serverConfirmed: true,
        canStartClass: false,
        validUntilMs: fixture.now + 600000,
      ),
    );
    await tester.pumpAndSettle();
    expect(enabled(tester), isFalse);
    expect(fixture.repository.requests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('local start cleanup failure retries only its own preparation', (
    tester,
  ) async {
    final fixture = PreparationFixture(count: 1);
    var results = 0;
    await mount(tester, fixture, onResult: (_) => results++);
    await tester.tap(find.text('전체 해제'));
    await tester.pumpAndSettle();
    final request = fixture.repository.value!;
    fixture.repository.cancelError = StateError('cleanup unavailable');
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(results, 0);
    expect(enabled(tester), isTrue);
    expect(find.text('수업을 시작하지 못했어요'), findsOneWidget);
    expect(fixture.repository.value, same(request));
    fixture.repository.cancelError = null;
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(results, 1);
    expect(fixture.repository.cancelled, [
      request.sessionId,
      request.sessionId,
    ]);
    expect(fixture.repository.requests, 1);
  });
}

class _NoRemoteWrites extends Fake implements PlaybackRepository {
  final calls = <Symbol>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    throw StateError(
      'Unexpected remote playback repository call: ${invocation.memberName}',
    );
  }
}

class _SilentBeep extends Fake implements BeepPlayer {
  @override
  Future<void> stop() async {}
}
