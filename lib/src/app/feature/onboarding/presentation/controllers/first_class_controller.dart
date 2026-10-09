import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/repositories/first_class_repository_impl.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';

import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';

part 'first_class_controller.g.dart';

typedef FirstClassScope = ({String userId, String centerId, bool centerReady});

@riverpod
Future<FirstClassScope?> firstClassScope(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final owner = await ref.watch(accountOwnerIdProvider.future);
  // Questionnaire role is deliberately not an access-control signal. STA-56
  // will supply membership scope; until then only the actual account owner enters.
  if (!ref.mounted || owner != user.id) return null;
  final onboarding = await ref.watch(onboardingControllerProvider.future);
  return (
    userId: user.id,
    centerId: onboarding.storeId.isEmpty ? 'pending' : onboarding.storeId,
    centerReady: onboarding.storeId.isNotEmpty && onboarding.completed,
  );
}

@Riverpod(keepAlive: true)
class FirstClassController extends _$FirstClassController {
  Future<void> _queue = Future.value();
  FirstClassScope? _scope;
  int _generation = 0;

  @override
  Future<FirstClassProgress?> build() async {
    final generation = ++_generation;
    _scope = null;
    final repository = ref.watch(firstClassRepositoryProvider);
    final scope = await ref.watch(firstClassScopeProvider.future);
    if (!ref.mounted || generation != _generation || scope == null) return null;
    final saved = await repository.load(scope.userId, scope.centerId);
    if (!ref.mounted || generation != _generation) return null;
    _scope = scope;
    final progress = saved.copyWith(
      centerReady: scope.centerReady,
      events: scope.centerReady && !saved.events.contains('center_completed')
          ? [...saved.events, 'center_completed']
          : saved.events,
    );
    await repository.save(scope.userId, scope.centerId, progress);
    if (!ref.mounted || generation != _generation) return null;
    for (final event in progress.events) {
      unawaited(
        repository
            .record(scope.userId, scope.centerId, progress.sessionId, event)
            .catchError((Object _) {}),
      );
    }
    ref.listen(activePlaybackSessionProvider, (_, _) => _observe());
    ref.listen(displayDevicesProvider, (_, _) => _observe());
    // Run after AsyncNotifier has published the loaded progress.
    Timer.run(() {
      if (ref.mounted && generation == _generation) _observe();
    });
    return progress;
  }

  void _observe() {
    final scope = _scope;
    final progress = state.value;
    if (scope == null || progress == null || progress.playedSessionId != null) {
      return;
    }
    final session = ref.read(activePlaybackSessionProvider).value;
    final devices = ref.read(displayDevicesProvider).value ?? const [];
    if (session == null ||
        session.ownerId != scope.userId ||
        progress.savedWorkoutId != session.workout.id ||
        !hasFirstPlaybackAck(session, devices)) {
      return;
    }
    final target = devices.firstWhere(
      (d) =>
          session.targetDeviceIds.contains(d.id) &&
          d.online &&
          d.paired &&
          d.displayState == 'auto' &&
          d.currentSessionId == session.id &&
          d.acknowledgedRevision >= session.revision,
    );
    unawaited(
      _change(
        (p) => p.copyWith(
          verifiedDeviceId: target.id,
          playedSessionId: session.id,
        ),
        events: const ['display_completed', 'playback_completed'],
      ).catchError((Object _) {}),
    );
  }

  Future<void> _change(
    FirstClassProgress Function(FirstClassProgress) update, {
    List<String> events = const [],
  }) {
    final scope = _scope;
    final generation = _generation;
    if (scope == null) return Future.value();
    final repository = ref.read(firstClassRepositoryProvider);
    final task = _queue.then((_) async {
      if (!ref.mounted || generation != _generation || state.value == null) {
        return;
      }
      final previous = state.value!;
      var next = update(previous);
      final pendingEvents = events
          .where((event) => !next.events.contains(event))
          .toSet();
      if (pendingEvents.isNotEmpty) {
        next = next.copyWith(events: [...next.events, ...pendingEvents]);
      }
      if (next == previous) return;
      await repository.save(scope.userId, scope.centerId, next);
      if (ref.mounted && generation == _generation) state = AsyncData(next);
      for (final event in pendingEvents) {
        // Telemetry must never block saving or playing a class.
        unawaited(
          repository
              .record(scope.userId, scope.centerId, next.sessionId, event)
              .catchError((Object _) {}),
        );
      }
    });
    _queue = task.catchError((Object _) {});
    return task;
  }

  Future<void> dismiss(bool value) =>
      _change((p) => p.copyWith(dismissed: value));
  Future<void> enter(FirstClassStep step) =>
      _change((p) => p, events: ['${step.name}_entered']);
  Future<void> help(FirstClassStep step) =>
      _change((p) => p, events: ['${step.name}_help']);
  Future<void> saved(String workoutId, {required String ownerId}) async {
    await future;
    if (_scope?.userId != ownerId) return Future.value();
    return _change(
      (p) => p.copyWith(savedWorkoutId: workoutId),
      events: const ['workout_completed'],
    );
  }

  Future<void> verified(String deviceId) => _change(
    (p) => p.copyWith(verifiedDeviceId: deviceId),
    events: const ['display_completed'],
  );
}
