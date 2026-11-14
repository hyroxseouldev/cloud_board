// Local-only preparation fixture shared by widget tests and the real web preview.
// Uses the production controller/router; no Firebase initialization or remote I/O.
import 'dart:async';

import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_preferences_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

class PreparationFixture {
  PreparationFixture({this.scene = 'ready', int count = 3}) {
    devices = [
      for (var i = 0; i < count; i++)
        DisplayDevice(
          id: 'tv-$i',
          name: ['메인 스튜디오 TV', '창가 트레이닝존 TV', '보조 TV'][i % 3],
          zoneId: 'main',
          zoneName: '스튜디오',
          paired: true,
          online: scene != 'offline' && !(scene == 'mixed' && i == 2),
          lastSeenAtMs: scene == 'offline' || (scene == 'mixed' && i == 2)
              ? 0
              : now,
          currentSessionId: 'ongoing-class',
          acknowledgedRevision: 99,
          playbackProtocol: 5,
          preparationProtocol: 1,
        ),
    ];
    repository = FixturePreparationRepository(scene, now);
  }
  final String scene;
  final int now = DateTime.now().millisecondsSinceEpoch;
  FixtureUsageSource source = FixtureUsageSource();
  final preferences = FixturePreparationPreferences();
  late final List<DisplayDevice> devices;
  late final FixturePreparationRepository repository;
  int deviceSubscriptions = 0;
  final health = StreamController<int>.broadcast();
  final deviceChanges = StreamController<List<DisplayDevice>>.broadcast();
  List<Override> get overrides => [
    accountOwnerIdProvider.overrideWith(
      (ref) => Stream.value('navigation-preview'),
    ),
    imageUsageSourceProvider.overrideWithValue(source),
    workoutPreferencesRepositoryProvider.overrideWithValue(preferences),
    displayDevicesProvider.overrideWith((ref) async* {
      deviceSubscriptions++;
      yield devices;
      yield* deviceChanges.stream;
    }),
    // Keep fake request/receipt and health clocks aligned even if a reviewer
    // leaves the local home tab open before entering preparation.
    serverTimeOffsetProvider.overrideWith((ref) async* {
      yield now - DateTime.now().millisecondsSinceEpoch;
      yield* Stream<int>.periodic(
        const Duration(seconds: 1),
        (_) => now - DateTime.now().millisecondsSinceEpoch,
      );
    }),
    displayHealthNowProvider.overrideWith((ref) async* {
      // Match the production health provider's subscription to server time.
      ref.watch(serverTimeOffsetProvider);
      yield now;
      yield* health.stream;
    }),
    deviceIdProvider.overrideWith((ref) async => 'local-fixture-controller'),
    displayPreparationRepositoryProvider.overrideWithValue(repository),
  ];
  void dispose() {
    unawaited(health.close());
    unawaited(deviceChanges.close());
  }
}

class FixtureUsageSource implements ImageUsageDataSource {
  int checks = 0;
  Object? error;
  @override
  Future<bool> enrolled() async {
    checks++;
    if (error != null) throw error!;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixturePreparationPreferences implements WorkoutPreferencesRepository {
  int freshReads = 0;
  Completer<void>? gate;
  Object? error;
  WorkoutPreferences? value;
  @override
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) async {
    if (fresh) freshReads++;
    await gate?.future;
    if (error != null) throw error!;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixturePreparationRepository implements DisplayPreparationRepository {
  FixturePreparationRepository(this.scene, this.now);
  String scene;
  final int now;
  int requests = 0;
  bool failRequest = false;
  Completer<void>? gate;
  DisplayPreparation? value;
  @override
  Future<void> request(DisplayPreparation request) async {
    requests++;
    await gate?.future;
    if (failRequest) throw StateError('PRIVATE_REQUEST_FAILURE');
    value = request;
  }

  @override
  Future<DisplayPreparation?> current() async => value;
  @override
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() async* {
    yield {
      for (final id in value!.targetDeviceIds)
        id: DisplayPreparationReceipt(
          sessionId: value!.sessionId,
          revision: value!.revision,
          manifestHash: value!.manifestHash,
          checkedAtMs: value!.expiresAtMs - 90000,
          status: scene == 'waiting'
              ? 'preparing'
              : (scene == 'error' || scene == 'mixed') && id == 'tv-1'
              ? 'failed'
              : 'ready',
          imageCount: value!.images.length,
          audioReady: true,
        ),
    };
  }

  @override
  Future<Map<String, DisplayPreparationReceipt>> receipts() =>
      watchReceipts().first;
  @override
  Future<void> cancel(String sessionId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
