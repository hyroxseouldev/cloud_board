import 'dart:async';

import 'package:cloud_board/src/app/bootstrap.dart';
import 'package:cloud_board/src/app/core/services/workout_media_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'bootstrap paints while initialization is pending and can retry',
    (tester) async {
      var initialization = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        AppBootstrap(
          initialize: () {
            calls++;
            return initialization.future;
          },
          builder: (isTv) =>
              MaterialApp(home: Text(isTv ? 'TV ready' : 'Mobile ready')),
        ),
      );
      expect(find.text('CloudBoard'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('TV ready'), findsNothing);
      expect(calls, 1);
      initialization.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('다시 시도'), findsOneWidget);
      initialization = Completer<bool>();
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      expect(calls, 2);
      initialization.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('TV ready'), findsOneWidget);
    },
  );

  test(
    'media initialization is lazy and exit during initialization hides last',
    () async {
      final initialized = Completer<WorkoutMediaController>();
      final delegate = _Media();
      var creations = 0;
      final media = LazyWorkoutMediaController(() {
        creations++;
        return initialized.future;
      });
      final received = <WorkoutMediaCommand>[];
      final subscription = media.commands.listen(received.add);
      await media.hide();
      expect(creations, 0);
      final show = media.show(_snapshot);
      final hide = media.hide();
      await Future<void>.delayed(Duration.zero);
      expect(creations, 1);
      initialized.complete(delegate);
      await Future.wait([show, hide]);
      expect(delegate.events, ['show', 'hide']);
      delegate.source.add(WorkoutMediaCommand.pause);
      await Future<void>.delayed(Duration.zero);
      expect(received, [WorkoutMediaCommand.pause]);
      await media.show(_snapshot);
      expect(creations, 1);
      await subscription.cancel();
      await media.dispose();
      await delegate.source.close();
    },
  );
}

const _snapshot = WorkoutMediaSnapshot(
  sessionId: 's',
  workoutName: 'W',
  slideName: 'S',
  statusLabel: '',
  durationMs: 60000,
  remainingMs: 60000,
  stepIndex: 0,
  isPaused: false,
);

class _Media implements WorkoutMediaController {
  final source = StreamController<WorkoutMediaCommand>.broadcast();
  final events = <String>[];
  @override
  Stream<WorkoutMediaCommand> get commands => source.stream;
  @override
  Future<void> show(WorkoutMediaSnapshot snapshot) async => events.add('show');
  @override
  Future<void> hide() async => events.add('hide');
}
