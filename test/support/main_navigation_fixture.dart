// Production router and screens with local data. No Firebase/session writes.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/services/workout_media_controller.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';

const previewUser = AuthUser(
  id: 'navigation-preview',
  email: 'coach@example.invalid',
  displayName: '코치',
  photoUrl: null,
);

List<Workout> navigationWorkouts({int count = 3, String imageSource = ''}) =>
    List.generate(
      count,
      (i) =>
          Workout.empty(
            'preview-$i',
            const WorkoutAuthor(
              id: 'navigation-preview',
              displayName: '코치',
              photoUrl: null,
            ),
          ).copyWith(
            name: ['HYROX 기초 체력', '토요일 팀 워크아웃', 'WAVE ZONE'][i % 3],
            folder: i.isEven ? 'Stationd' : '팀 수업',
            countdownSeconds: 0,
            updatedAt: DateTime(2026, 10, 10).subtract(Duration(minutes: i)),
            modules: [
              WorkoutModule.empty('slide-$i').copyWith(
                name: 'WAVE ZONE',
                workSeconds: 800,
                restSeconds: 60,
                sets: 1,
                beep: false,
                imageSource: imageSource,
              ),
            ],
          ),
    );

PlaybackSession navigationSession(Workout workout) => PlaybackSession(
  id: 'preview-session',
  ownerId: previewUser.id,
  zoneId: 'main',
  targetDeviceIds: const ['preview-tv'],
  workout: workout,
  status: PlaybackStatus.paused,
  stepIndex: 0,
  remainingMs: 480000,
  anchorServerMs: DateTime.now().millisecondsSinceEpoch,
  revision: 1,
  updatedByDeviceId: 'preview-controller',
);

class NavigationPreviewData {
  NavigationPreviewData({
    bool active = true,
    int count = 3,
    String imageSource = '',
  }) {
    repository = NavigationWorkoutRepository(
      navigationWorkouts(count: count, imageSource: imageSource),
    );
    session = active && repository.items.isNotEmpty
        ? navigationSession(repository.items.first)
        : null;
    commands = NavigationCommands(this);
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) async* {
          yield previewUser;
          yield* users.stream;
        }),
        accountOwnerIdProvider.overrideWith((ref) => Stream.value(null)),
        onboardingRequiredProvider.overrideWith((ref) async => false),
        firstClassControllerProvider.overrideWith(_NoFirstClass.new),
        deviceModeControllerProvider.overrideWith(NavigationMode.new),
        androidTvProvider.overrideWith((ref) async => false),
        displayDevicesProvider.overrideWith(
          (ref) => Stream.value(const [
            DisplayDevice(
              id: 'preview-tv',
              name: '메인 디스플레이',
              zoneId: 'main',
              zoneName: '메인',
              online: true,
              lastSeenAtMs: 0,
              currentSessionId: 'preview-session',
              acknowledgedRevision: 1,
              paired: true,
            ),
          ]),
        ),
        activePlaybackSessionProvider.overrideWith((ref) async* {
          yield session;
          yield* sessions.stream;
        }),
        playbackConnectionProvider.overrideWith((ref) => Stream.value(true)),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        playbackActionControllerProvider.overrideWith(() => commands),
        workoutMediaControllerProvider.overrideWith((ref) => _PreviewMedia()),
        workoutRepositoryProvider.overrideWith((ref) async => repository),
        libraryFoldersProvider.overrideWith(
          (ref) => Stream.value(['Stationd', '팀 수업']),
        ),
        slideTemplatesControllerProvider.overrideWith2(
          (scope) => _PreviewSlides(repository.items),
        ),
        accountWorkoutPreferencesProvider.overrideWith(
          (ref, owner) async => const WorkoutPreferences(),
        ),
      ],
    );
  }
  final users = StreamController<AuthUser?>.broadcast();
  final sessions = StreamController<PlaybackSession?>.broadcast();
  PlaybackSession? session;
  late final NavigationWorkoutRepository repository;
  late final NavigationCommands commands;
  late final ProviderContainer container;
  void setSession(PlaybackSession? value) {
    session = value;
    sessions.add(value);
  }

  void dispose() {
    container.dispose();
    unawaited(users.close());
    unawaited(sessions.close());
  }
}

class MainNavigationPreview extends ConsumerWidget {
  const MainNavigationPreview({super.key, this.textScale = 1});
  final double textScale;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'CloudBoard 내비게이션 미리보기',
    debugShowCheckedModeBanner: false,
    theme: XonTheme.light,
    routerConfig: ref.watch(appRouterProvider),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: XonTheme.responsiveBuilder(context, child),
    ),
  );
}

class NavigationMode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
  @override
  DeviceMode get currentMode => state.value ?? DeviceMode.controller;
  @override
  Future<bool> setMode(DeviceMode value) async {
    state = AsyncData(value);
    return true;
  }
}

class _NoFirstClass extends FirstClassController {
  @override
  Future<FirstClassProgress?> build() async => null;
}

class _PreviewSlides extends SlideTemplatesController {
  _PreviewSlides(this.workouts);
  final List<Workout> workouts;
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value([
    for (final workout in workouts)
      workout.modules.first.copyWith(category: workout.folder),
  ]);
}

class NavigationCommands extends PlaybackActionController {
  NavigationCommands(this.data);
  final NavigationPreviewData data;
  int transports = 0;
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  @override
  Future<bool> pause(int remainingMs) async {
    transports++;
    data.setSession(
      data.session!.copyWith(
        status: PlaybackStatus.paused,
        remainingMs: remainingMs,
        revision: data.session!.revision + 1,
      ),
    );
    return true;
  }

  @override
  Future<bool> resume() async {
    transports++;
    data.setSession(
      data.session!.copyWith(
        status: PlaybackStatus.playing,
        anchorServerMs: DateTime.now().millisecondsSinceEpoch,
        revision: data.session!.revision + 1,
      ),
    );
    return true;
  }
}

class NavigationWorkoutRepository implements WorkoutRepository {
  NavigationWorkoutRepository(this.items);
  final List<Workout> items;
  int loads = 0;
  @override
  Future<List<Workout>> load() async => items;
  @override
  Future<Workout?> loadOne(String id) async =>
      items.where((item) => item.id == id).firstOrNull;
  @override
  Stream<List<Workout>> watch() async* {
    loads++;
    yield List.of(items);
  }

  @override
  Stream<List<WorkoutSummary>> watchSummaries({bool requireServer = false}) =>
      watch().map((items) => items.map(summarizeWorkout).toList());
  @override
  Future<Workout> save(
    Workout workout, {
    void Function(int, int)? onProgress,
  }) async {
    items.removeWhere((item) => item.id == workout.id);
    items.add(workout);
    return workout;
  }

  @override
  Future<void> delete(String id) async =>
      items.removeWhere((item) => item.id == id);
}

class _PreviewMedia implements WorkoutMediaController {
  @override
  Stream<WorkoutMediaCommand> get commands => const Stream.empty();
  @override
  Future<void> show(WorkoutMediaSnapshot snapshot) async {}
  @override
  Future<void> hide() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> navigationPreviewImage() async {
  final bytes = await rootBundle.load(
    'assets/slide_templates/stationd_wed_original.png',
  );
  return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
}
