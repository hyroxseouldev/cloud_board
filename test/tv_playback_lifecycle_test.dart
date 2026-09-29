import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

void main() {
  for (final isTv in [true, false]) {
    testWidgets('foreground-only gate is TV-specific: $isTv', (tester) async {
      final audio = _Audio();
      final recovery = _Recovery();
      final container = ProviderContainer(
        overrides: [
          beepPlayerProvider.overrideWith((ref) => audio),
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
  Completer<void>? pending;
  @override
  AsyncValue<void> build() => const AsyncData(null);
  @override
  Future<void> recover({bool restartTransport = true}) async {
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
