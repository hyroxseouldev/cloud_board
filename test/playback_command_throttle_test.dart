import 'dart:async';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late _Actions actions;
  late ProviderContainer container;
  late PlaybackActionController commands;

  setUp(() {
    actions = _Actions();
    container = ProviderContainer(
      overrides: [
        playbackActionsProvider.overrideWith((ref) => actions),
        deviceIdProvider.overrideWith((ref) async => 'controller'),
      ],
    );
    commands = container.read(playbackActionControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  testWidgets('first command is immediate and rapid mixed taps are dropped', (
    tester,
  ) async {
    expect(await commands.pause(1000), isTrue);
    expect(await commands.resume(), isFalse);
    expect(await commands.seek(stepIndex: 1, durationMs: 1000), isFalse);
    expect(actions.calls, ['pause']);
    expect(commands.canSendTransportCommand, isFalse);
    await tester.pump(const Duration(milliseconds: 350));
    expect(commands.canSendTransportCommand, isTrue);
    expect(await commands.seek(stepIndex: 1, durationMs: 1000), isTrue);
    expect(actions.calls, ['pause', 'seek']);
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('slow requests stay single flight after cooldown expires', (
    tester,
  ) async {
    actions.pending = Completer<void>();
    final first = commands.pause(1000);
    await tester.pump(const Duration(seconds: 1));
    expect(await commands.resume(), isFalse);
    expect(await commands.seek(stepIndex: 1, durationMs: 1000), isFalse);
    expect(actions.calls, ['pause']);
    actions.pending!.complete();
    expect(await first, isTrue);
    expect(await commands.resume(), isTrue);
    expect(actions.calls, ['pause', 'resume']);
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('failure permits retry and automatic sync bypasses cooldown', (
    tester,
  ) async {
    actions.fail = true;
    expect(await commands.pause(1000), isFalse);
    expect(container.read(playbackActionControllerProvider).hasError, isTrue);
    actions.fail = false;
    expect(await commands.pause(1000), isTrue);
    expect(await commands.syncStep(stepIndex: 1, durationMs: 1000), isTrue);
    expect(await commands.complete(), isTrue);
    expect(actions.calls, ['pause', 'pause', 'seek', 'complete']);
    await tester.pump(const Duration(milliseconds: 350));
  });
}

class _Actions extends Fake implements PlaybackActions {
  final calls = <String>[];
  Completer<void>? pending;
  bool fail = false;

  Future<void> run(String name) async {
    calls.add(name);
    if (fail) throw StateError('offline');
    if (pending != null) await pending!.future;
  }

  @override
  Future<void> pause({required int remainingMs, required String deviceId}) =>
      run('pause');
  @override
  Future<void> resume({required String deviceId}) => run('resume');
  @override
  Future<void> seek({
    required int stepIndex,
    required int durationMs,
    required String deviceId,
  }) => run('seek');
  @override
  Future<void> complete({required String deviceId}) => run('complete');
}
