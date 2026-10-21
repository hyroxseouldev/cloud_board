import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

void main() {
  testWidgets('wake retries automatically after the first server failure', (
    tester,
  ) async {
    final audio = _Audio();
    final recovery = _Recovery();
    final container = ProviderContainer(
      overrides: [
        activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
        beepPlayerProvider.overrideWith((ref) => audio),
        accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
        playbackConnectionProvider.overrideWith((ref) => const Stream.empty()),
        playbackRecoveryControllerProvider.overrideWith(() => recovery),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TvPlaybackLifecycle(isTv: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    recovery.finish();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final first = recovery.calls;
    recovery.finish(fail: true);
    await tester.pump();
    expect(container.read(tvPlaybackVisibleProvider), isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(
      recovery.calls,
      first + 1,
      reason: 'Wake recovery must retry without another lifecycle event or tap',
    );
    recovery.finish();
    await tester.pump();
    expect(container.read(tvPlaybackVisibleProvider), isTrue);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'three network disconnects each recover without replaying a class command',
    (tester) async {
      final audio = _Audio(), recovery = _Recovery();
      final connection = StreamController<bool>.broadcast();
      final owner = StreamController<String?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
          beepPlayerProvider.overrideWith((_) => audio),
          playbackRecoveryControllerProvider.overrideWith(() => recovery),
          accountOwnerIdProvider.overrideWith((_) => owner.stream),
          playbackConnectionProvider.overrideWith((_) => connection.stream),
        ],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TvPlaybackLifecycle(isTv: true, child: SizedBox()),
        ),
      );
      owner.add('owner');
      await tester.pump();
      await tester.pump();
      recovery.finish();
      await tester.pump();
      connection.add(true);
      await tester.pump();
      recovery.finish();
      await tester.pump();
      for (var cycle = 0; cycle < 3; cycle++) {
        connection.add(false);
        await tester.pump();
        expect(container.read(tvPlaybackVisibleProvider), isFalse);
        recovery.finish(fail: true);
        await tester.pump();
        final calls = recovery.calls;
        connection.add(true);
        await tester.pump();
        expect(recovery.calls, calls + 1);
        recovery.finish();
        await tester.pump();
        expect(container.read(tvPlaybackVisibleProvider), isTrue);
      }
      expect(container.exists(playbackActionControllerProvider), isFalse);
      // Unpairing removes the scope and cancels a queued retry permanently.
      connection.add(false);
      await tester.pump();
      recovery.finish(fail: true);
      await tester.pump();
      owner.add(null);
      await tester.pump();
      await tester.pump();
      final calls = recovery.calls;
      await tester.pump(const Duration(seconds: 40));
      expect(recovery.calls, calls);
      expect(audio.values.last, isFalse);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await owner.close();
      await connection.close();
    },
  );

  testWidgets(
    'wake backoff is bounded and a later background cancels all retry timers',
    (tester) async {
      final audio = _Audio(), recovery = _Recovery();
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
          beepPlayerProvider.overrideWith((_) => audio),
          playbackRecoveryControllerProvider.overrideWith(() => recovery),
          accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
          playbackConnectionProvider.overrideWith((_) => const Stream.empty()),
        ],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TvPlaybackLifecycle(isTv: true, child: SizedBox()),
        ),
      );
      await tester.pump();
      recovery.finish();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      recovery.finish(fail: true);
      await tester.pump();
      final first = recovery.calls;
      for (final seconds in [1, 2, 4, 8, 16]) {
        await tester.pump(Duration(seconds: seconds));
        recovery.finish(fail: true);
        await tester.pump();
      }
      expect(recovery.calls, first + 5);
      await tester.pump(const Duration(seconds: 60));
      expect(recovery.calls, first + 5);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      recovery.finish(fail: true);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final calls = recovery.calls;
      await tester.pump(const Duration(seconds: 60));
      expect(recovery.calls, calls);
      expect(audio.values.last, isFalse);
      expect(container.read(tvPlaybackVisibleProvider), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      recovery.finish();
      await tester.pump();
      container.dispose();
    },
  );

  testWidgets('cold start stays muted until the first server confirmation', (
    tester,
  ) async {
    final audio = _Audio(), recovery = _Recovery();
    final container = ProviderContainer(
      overrides: [
        activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
        tvPlaybackVisibleProvider.overrideWith(
          () => TvPlaybackVisible(initiallyVisible: false),
        ),
        beepPlayerProvider.overrideWith((_) => audio),
        playbackRecoveryControllerProvider.overrideWith(() => recovery),
        accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
        playbackConnectionProvider.overrideWith((_) => const Stream.empty()),
      ],
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TvPlaybackLifecycle(isTv: true, child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(container.read(tvPlaybackVisibleProvider), isFalse);
    expect(audio.values, isNot(contains(true)));
    recovery.finish();
    await tester.pump();
    expect(container.read(tvPlaybackVisibleProvider), isTrue);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final isTv in [true, false]) {
    testWidgets('foreground-only gate is TV-specific: $isTv', (tester) async {
      final audio = _Audio();
      final recovery = _Recovery();
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith((_) => Stream.value(null)),
          beepPlayerProvider.overrideWith((ref) => audio),
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          playbackConnectionProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
          playbackRecoveryControllerProvider.overrideWith(() => recovery),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TvPlaybackLifecycle(isTv: isTv, child: const SizedBox()),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      recovery.finish();
      await tester.pump();
      audio.values.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(container.read(tvPlaybackVisibleProvider), !isTv);
      expect(audio.values, isTv ? everyElement(isFalse) : isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      if (isTv) {
        expect(container.read(tvPlaybackVisibleProvider), isFalse);
        recovery.finish(fail: true);
        await tester.pump();
        expect(container.read(tvPlaybackVisibleProvider), isFalse);
        // A retry in the foreground can release the gate.
        final retry = recovery.recover(restartTransport: false);
        recovery.finish();
        await retry;
        await tester.pump();
        expect(container.read(tvPlaybackVisibleProvider), isTrue);
        // Background while refresh is pending must not re-enable old playback.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        recovery.finish();
        await tester.pump();
        expect(container.read(tvPlaybackVisibleProvider), isFalse);
        expect(audio.values.last, isFalse);
      }
      expect(
        container.exists(playbackActionControllerProvider),
        isFalse,
        reason: 'Never pause/end the shared class',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      recovery.finish();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }
}

class _Audio extends Fake implements BeepPlayer {
  final values = <bool>[];
  @override
  Future<void> setEnabled(bool value) async {
    values.add(value);
  }
}

class _Recovery extends PlaybackRecoveryController {
  int calls = 0;
  Completer<void>? pending;
  @override
  AsyncValue<void> build() => const AsyncData(null);
  @override
  Future<void> recover({bool restartTransport = true}) async {
    calls++;
    state = const AsyncLoading();
    pending = Completer<void>();
    await pending!.future;
  }

  void finish({bool fail = false}) {
    if (pending == null || pending!.isCompleted) return;
    state = fail
        ? AsyncError(StateError('offline'), StackTrace.current)
        : const AsyncData(null);
    pending!.complete();
  }
}
