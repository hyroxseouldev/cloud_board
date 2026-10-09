import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/diagnostics/workout_diagnostic_sink.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/workout_catalog_fixture.dart';

final _workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'u', displayName: 'Private name', photoUrl: null),
);

class _Sink implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  bool fail = false;
  @override
  Future<void> send(DiagnosticEvent event) async {
    events.add(event);
    if (fail) throw StateError('Telemetry unavailable');
  }
}

class _Repository implements WorkoutRepository {
  Object? failure;
  @override
  Future<Workout> save(
    Workout workout, {
    void Function(int, int)? onProgress,
  }) async {
    if (failure != null) throw failure!;
    return workout;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Catalog extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() => Stream.value([]);
}

void main() {
  for (final duplicate in [false, true]) {
    test(
      '${duplicate ? 'duplicate' : 'save'} reports permission failure without opening error details',
      () async {
        final sink = _Sink()..fail = true;
        final reporter = ErrorReporter(sink);
        final error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
        final repo = _Repository()..failure = error;
        final container = ProviderContainer(
          overrides: [
            errorReporterProvider.overrideWithValue(reporter),
            activePlaybackSessionProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
            saveWorkoutProvider.overrideWith((ref) async => SaveWorkout(repo)),
            fixtureWorkoutDetails,
            workoutControllerProvider.overrideWith(_Catalog.new),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          workoutActionControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final actions = container.read(
          workoutActionControllerProvider.notifier,
        );
        if (duplicate) {
          expect(await actions.duplicate(_workout, 'copy'), isFalse);
        } else {
          expect(await actions.save(_workout), isNull);
        }
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(workoutActionControllerProvider).error,
          same(error),
        );
        final event = sink.events.single;
        expect(event.code, 'cloud_firestore/permission-denied');
        expect(
          event.context['action'],
          duplicate ? 'workout.duplicate' : 'workout.save',
        );
        expect(event.context['workoutId'], duplicate ? 'copy' : 'w');
        expect(event.toJson().toString(), isNot(contains('Private name')));
        // The optional debug details dialog must reuse the captured event.
        expect(
          reporter.capture(error, StackTrace.current, action: 'ui.error'),
          same(event),
        );
        expect(sink.events, hasLength(1));
        repo.failure = null;
        expect(await actions.save(_workout), isNotNull);
        expect(sink.events, hasLength(1));
      },
    );
  }
  test('native save alerts survive Crashlytics failure; unrelated events stay in primary sink', () async {
    final primary = _Sink()..fail = true;
    final alerts = _Sink();
    final reporter = ErrorReporter(
      WorkoutDiagnosticSink(primary: primary, alerts: alerts),
    );
    reporter.capture(
      StateError('save'),
      StackTrace.current,
      action: 'workout.save',
    );
    reporter.capture(
      StateError('copy'),
      StackTrace.current,
      action: 'workout.duplicate',
    );
    reporter.capture(
      StateError('other'),
      StackTrace.current,
      action: 'playback.pause',
    );
    await Future<void>.delayed(Duration.zero);
    expect(primary.events, hasLength(3));
    expect(alerts.events.map((e) => e.context['action']), [
      'workout.save',
      'workout.duplicate',
    ]);
  });
}
