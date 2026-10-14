import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';

import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const recoveryTargets = ['tv-a', 'tv-b', 'tv-c'];
Map<String, dynamic> recoverySession({
  String id = 'class',
  int revision = 1,
  String status = 'playing',
  int? anchor,
}) => {
  ...PlaybackSessionModel.fromWorkout(
    id: id,
    ownerId: 'owner',
    zoneId: 'main',
    targetDeviceIds: recoveryTargets,
    workout:
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'owner',
            displayName: 'Coach',
            photoUrl: null,
          ),
        ).copyWith(
          countdownSeconds: 0,
          modules: [
            WorkoutModule.empty('first')
                .copyWith(workSeconds: 60, restSeconds: 0, sets: 1),
            WorkoutModule.empty('second')
                .copyWith(workSeconds: 90, restSeconds: 0, sets: 1),
          ],
        ),
    stepIndex: 0,
    durationMs: 60000,
    deviceId: 'phone',
  ).toJson(),
  'revision': revision,
  'status': status,
  'anchorServerMs': anchor ?? DateTime.now().millisecondsSinceEpoch - 5000,
};

/// Real source -> repository -> actions -> generated controllers. Only the SDK
/// transport and disk are replaced; SDK cache can deliberately lag the REST read.
class RecoveryHarness {
  RecoveryHarness(Map<String, dynamic> initial) {
    db = RecoveryDatabase(initial);
    telemetry = OperationTelemetry(
      readAccount: () => 'owner',
      emit: (event, _) async => events.add(event),
    );
    container = ProviderContainer(
      overrides: [
        errorReporterProvider.overrideWithValue(ErrorReporter(diagnostics)),
        playbackRepositoryProvider.overrideWith((ref) {
          // Match production ownership: the provider constructs its data source
          // and repository, while the fake only replaces network and disk.
          source = PlaybackRealtimeDataSource(
            db,
            'owner',
            serverRead: (_) async {
              restReads++;
              return await readServer();
            },
          );
          repository = PlaybackRepositoryImpl(source, cache, 'owner');
          return repository;
        }),
        playbackActionsProvider.overrideWith(
          (ref) => PlaybackActions(repository),
        ),
        deviceIdProvider.overrideWith((ref) async => 'phone'),
        displayDevicesProvider.overrideWith(
          (ref) => Stream.multi((sink) {
            sink.add(devices);
            final sub = deviceEvents.stream.listen(sink.add);
            sink.onCancel = sub.cancel;
          }),
        ),
        operationTelemetryProvider.overrideWithValue(telemetry),
      ],
    );
    container.listen(activePlaybackSessionProvider, (_, _) {});
    container.listen(playbackConnectionProvider, (_, _) {});
    container.listen(displayDevicesProvider, (_, _) {});
  }
  late final RecoveryDatabase db;
  late final PlaybackRealtimeDataSource source;
  late final PlaybackRepositoryImpl repository;
  late final ProviderContainer container;
  final cache = RecoveryCache();
  final diagnostics = RecoveryDiagnostics();
  final deviceEvents = StreamController<List<DisplayDevice>>.broadcast();
  final events = <Map<String, dynamic>>[];
  late final OperationTelemetry telemetry;
  int restReads = 0;
  late Future<Object?> Function() readServer = () async => db.server;
  List<DisplayDevice> devices = [];
  PlaybackActionController get commands =>
      container.read(playbackActionControllerProvider.notifier);
  PlaybackRecoveryController get recovery =>
      container.read(playbackRecoveryControllerProvider.notifier);
  void acknowledgeHealthyTvs() {
    final current = db.server! as Map;
    devices = [
      for (final id in recoveryTargets)
        DisplayDevice(
          id: id,
          name: id,
          zoneId: 'main',
          zoneName: 'main',
          online: id != 'tv-c',
          lastSeenAtMs: DateTime.now().millisecondsSinceEpoch,
          currentSessionId: current['id'] as String,
          acknowledgedRevision: id == 'tv-c' ? 1 : current['revision'] as int,
          paired: true,
        ),
    ];
    deviceEvents.add(devices);
  }

  bool _disposed = false;
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
    await source.dispose();
    await db.events.close();
    await deviceEvents.close();
  }
}

class RecoveryCache extends Fake implements PlaybackSessionLocalDataSource {
  PlaybackSessionModel? value;
  @override
  Future<PlaybackSessionModel?> load() async => value;
  @override
  Future<void> save(PlaybackSessionModel session) async => value = session;
  @override
  Future<void> clear() async => value = null;
}

class RecoveryDatabase extends Fake implements FirebaseDatabase {
  RecoveryDatabase(Object? initial) : cached = initial, server = initial;
  Object? cached, server;
  bool connected = true;
  // Playback mutations and best-effort telemetry are separate effects.
  int transactions = 0, writes = 0, operationEventWrites = 0;
  final operationEvents = <String, Map<String, dynamic>>{};
  Future<void> Function()? beforeTransaction;
  final events = StreamController<DatabaseEvent>.broadcast();
  final transport = <String>[];
  void deliver(Object? value) {
    server = value;
    events.add(RecoveryEvent(value));
  }

  @override
  Future<void> goOffline() async => transport.add('offline');
  @override
  Future<void> goOnline() async => transport.add('online');
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path!);
}

class _Reference extends Fake implements DatabaseReference {
  _Reference(this.db, this.path);
  final RecoveryDatabase db;
  @override
  final String path;
  @override
  DatabaseReference child(String path) => _Reference(db, '${this.path}/$path');
  @override
  Future<void> set(Object? value) async {
    final eventPath = RegExp(r'^users/owner/operations/events/[^/]+$');
    if (!eventPath.hasMatch(path) || value is! Map) {
      throw StateError('Unexpected recovery fixture write: $path');
    }
    db.operationEventWrites++;
    db.operationEvents[path] = Map<String, dynamic>.from(value);
  }

  @override
  Stream<DatabaseEvent> get onValue {
    if (path == '.info/connected') {
      return Stream.value(RecoveryEvent(db.connected));
    }
    if (path == '.info/serverTimeOffset') return Stream.value(RecoveryEvent(0));
    return Stream.multi((sink) {
      sink.add(RecoveryEvent(db.cached));
      final sub = db.events.stream.listen(sink.add);
      sink.onCancel = sub.cancel;
    });
  }

  @override
  Future<DataSnapshot> get() async => _Snapshot(db.server);
  @override
  Future<TransactionResult> runTransaction(
    TransactionHandler handler, {
    bool applyLocally = true,
  }) async {
    db.transactions++;
    await db.beforeTransaction?.call();
    final result = handler(db.server);
    if (result.aborted) return _Result(false, db.server);
    final value = Map<String, dynamic>.from(result.value! as Map)
      ..['anchorServerMs'] = DateTime.now().millisecondsSinceEpoch;
    db.writes++;
    db.deliver(value);
    return _Result(true, value);
  }
}

class RecoveryEvent extends Fake implements DatabaseEvent {
  RecoveryEvent(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
}

class _Snapshot extends Fake implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
}

class _Result extends Fake implements TransactionResult {
  _Result(this.committed, Object? value) : snapshot = _Snapshot(value);
  @override
  final bool committed;
  @override
  final DataSnapshot snapshot;
}

class RecoveryDiagnostics implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async {
    events.add(event);
  }
}
