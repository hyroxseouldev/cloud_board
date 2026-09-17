import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/domain/repositories/playback_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';

class _Playback extends PlaybackActions {
  _Playback() : super(_UnusedRepository());
  int checks = 0;
  Future<bool> Function() response = () async => false;
  @override
  Future<bool> hasRunningSession() {
    checks++;
    return response();
  }
}

class _UnusedRepository implements PlaybackRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final loading in [false, true]) {
    test(
      'does not query playback before owner is ready (loading=$loading)',
      () async {
        final playback = _Playback()
          ..response = () async => throw StateError('연결된 매장을 찾을 수 없습니다.');
        final pending = Completer<String?>();
        final container = ProviderContainer(
          overrides: [
            accountOwnerIdProvider.overrideWith(
              (ref) => loading ? pending.future.asStream() : Stream.value(null),
            ),
            playbackActionsProvider.overrideWithValue(playback),
          ],
        );
        addTearDown(container.dispose);
        container.listen(accountOwnerIdProvider, (_, _) {});
        await container.pump();
        if (!loading) await container.read(accountOwnerIdProvider.future);
        await container
            .read(scheduleRunnerControllerProvider.notifier)
            .runDue();
        expect(playback.checks, 0);
      },
    );
  }
  test(
    'no eligible schedules means zero playback reads across repeated ticks',
    () async {
      final playback = _Playback()
        ..response = () async => throw StateError('must not read');
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          workoutSchedulesProvider.overrideWith((ref) => Stream.value([])),
          playbackActionsProvider.overrideWithValue(playback),
        ],
      );
      addTearDown(container.dispose);
      container.listen(accountOwnerIdProvider, (_, _) {});
      container.listen(workoutSchedulesProvider, (_, _) {});
      await container.read(accountOwnerIdProvider.future);
      await container.read(workoutSchedulesProvider.future);
      final runner = container.read(scheduleRunnerControllerProvider.notifier);
      for (var i = 0; i < 180; i++) {
        await runner.runDue();
      }
      expect(playback.checks, 0);
      expect(
        container.read(scheduleRunnerControllerProvider).hasError,
        isFalse,
      );
    },
  );
  test(
    'network failure is caught, concurrent ticks skip, and next tick retries',
    () async {
      final pending = Completer<bool>();
      final playback = _Playback()..response = () => pending.future;
      final container = ProviderContainer(
        overrides: [
          accountOwnerIdProvider.overrideWith((ref) => Stream.value('owner')),
          playbackActionsProvider.overrideWithValue(playback),
          workoutSchedulesProvider.overrideWith(
            (ref) => Stream.value([
              WorkoutSchedule(
                id: 'due',
                workoutId: 'w',
                workoutName: 'w',
                enabled: true,
                createdAtMs: 0,
                lastOccurrenceKey: null,
                targetDeviceIds: [],
                weekdays: [DateTime.now().weekday],
                hour: DateTime.now().hour,
                minute: DateTime.now().minute,
              ),
            ]),
          ),
          displayDevicesProvider.overrideWith(
            (ref) => Stream.error(StateError('fixture stop')),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(accountOwnerIdProvider, (_, _) {});
      await container.pump();
      await container.read(accountOwnerIdProvider.future);
      container.listen(workoutSchedulesProvider, (_, _) {});
      await container.pump();
      final runner = container.read(scheduleRunnerControllerProvider.notifier);
      final first = runner.runDue();
      await runner.runDue();
      await Future<void>.delayed(Duration.zero);
      expect(playback.checks, 1);
      pending.completeError(StateError('network down'));
      await first;
      expect(container.read(scheduleRunnerControllerProvider).hasError, isTrue);
      playback.response = () async => true;
      await runner.runDue();
      expect(playback.checks, 2);
      expect(
        container.read(scheduleRunnerControllerProvider).hasError,
        isFalse,
      );
    },
  );
}
