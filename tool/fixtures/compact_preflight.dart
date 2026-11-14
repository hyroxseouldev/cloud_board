import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
// Local-only entrypoint: no Firebase initialization, account or server writes.
// flutter build web --target tool/fixtures/compact_preflight.dart --no-web-resources-cdn
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/display_preparation_repository.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_preferences_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart';

void main() {
  final params = Uri.base.queryParameters;
  final scene = params['scene'] ?? 'ready';
  final scale = double.tryParse(params['scale'] ?? '') ?? 1;
  final image = Uri.base.resolve('/fixture-image.png?scene=$scene').toString();
  final workout =
      Workout.empty(
        'fixture',
        const WorkoutAuthor(id: 'local', displayName: 'Local', photoUrl: null),
      ).copyWith(
        name: '토요일 전신 서킷 트레이닝',
        countdownImageSource: image,
        modules: [
          for (var i = 0; i < 6; i++)
            WorkoutModule.empty('m$i')
                .copyWith(name: '스쿼트 ${i + 1}', imageSource: '$image&slide=$i'),
        ],
      );
  final devices = [
    if (scene != 'solo' && scene != 'empty')
      for (var i = 0; i < 3; i++)
        DisplayDevice(
          id: '$i',
          name: ['메인 스튜디오 TV', '창가 트레이닝존의 긴 이름 디스플레이', '보조 TV'][i],
          zoneId: 'main',
          zoneName: '스튜디오',
          online: scene != 'offline',
          lastSeenAtMs: scene == 'offline'
              ? 0
              : DateTime.now().millisecondsSinceEpoch,
          currentSessionId: null,
          acknowledgedRevision: 0,
          paired: true,
          playbackProtocol: 5,
          preparationProtocol: i == 2 ? 0 : 1,
        ),
  ];
  final session = PlaybackSessionModel.fromWorkout(
    id: 'local-session',
    ownerId: 'local',
    zoneId: 'main',
    targetDeviceIds: ['0'],
    workout: workout,
    stepIndex: 0,
    durationMs: 60000,
    deviceId: 'fixture',
  ).toEntity();
  final player = playerControllerProvider(
    workout,
    startModule: 0,
    sessionId: 'local-session',
    canControl: true,
  );
  runApp(
    ProviderScope(
      overrides: [
        accountOwnerIdProvider.overrideWith((ref) => Stream.value('local')),
        activePlaybackSessionProvider.overrideWith(
          (ref) => Stream.value(session),
        ),
        playbackConnectionProvider.overrideWith((ref) => Stream.value(true)),
        androidTvProvider.overrideWith((ref) async => false),
        player.overrideWith(() => _Player(scene == 'countdown')),
        imageUsageSourceProvider.overrideWithValue(_Source(scene)),
        workoutPreferencesRepositoryProvider.overrideWithValue(_Preferences()),
        displayDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        displayPreparationRepositoryProvider.overrideWithValue(
          _Preparation(scene),
        ),
      ],
      child: MaterialApp(
        theme: XonTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: scene == 'controller' || scene == 'countdown'
            ? const WorkoutPlayerScreen(
                workoutId: 'fixture',
                startModule: 0,
                sessionId: 'local-session',
              )
            : WorkoutPreparationPage(workout: workout),
      ),
    ),
  );
}

class _Source implements ImageUsageDataSource {
  _Source(this.scene);
  final String scene;
  @override
  Future<bool> enrolled() async {
    if (scene == 'permission') {
      throw const ImageUsageFailure('entitlement_unverified');
    }
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences implements WorkoutPreferencesRepository {
  @override
  Future<WorkoutPreferences?> load(
    String ownerId, {
    bool fresh = false,
  }) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preparation implements DisplayPreparationRepository {
  _Preparation(this.scene);
  final String scene;
  DisplayPreparation? value;
  @override
  Future<void> request(DisplayPreparation request) async {
    value = request;
  }

  @override
  Future<DisplayPreparation?> current() async => value;
  @override
  Stream<Map<String, DisplayPreparationReceipt>> watchReceipts() =>
      Stream.value({
        for (final id in value!.targetDeviceIds)
          id: DisplayPreparationReceipt(
            sessionId: value!.sessionId,
            revision: value!.revision,
            manifestHash: value!.manifestHash,
            checkedAtMs: DateTime.now().millisecondsSinceEpoch,
            status: scene == 'waiting'
                ? 'preparing'
                : scene == 'error' && id == '1'
                ? 'failed'
                : 'ready',
            imageCount: value!.images.length,
            audioReady: true,
          ),
      });
  @override
  Future<void> cancel(String sessionId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends PlayerController {
  _Player(this.countdown);
  final bool countdown;
  @override
  PlayerState build(
    Workout workout, {
    int startModule = 0,
    String? sessionId,
    bool canControl = true,
  }) => PlayerState(
    steps: buildPlayerSteps(workout),
    index: 0,
    remainingMs: 60000,
    isPaused: false,
    countdownMs: countdown ? 5000 : 0,
  );
  @override
  Future<void> selectModule(int moduleIndex) async {
    state = state.copyWith(
      index: state.steps.indexWhere((step) => step.moduleIndex == moduleIndex),
      remainingMs: 60000,
    );
  }

  @override
  Future<void> next() =>
      selectModule((state.steps[state.index].moduleIndex + 1).clamp(0, 5));
  @override
  Future<void> previous() =>
      selectModule((state.steps[state.index].moduleIndex - 1).clamp(0, 5));
}
