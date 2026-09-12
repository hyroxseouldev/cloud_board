import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/profile/domain/entities/user_profile.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/user_profile_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_player_screen.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

// Run from repository root: flutter test tool/play_store_capture_test.dart
// Captures production widgets with Android styling and local sample data only.
void main() {
  testWidgets('export Korean Google Play source screenshots', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (message) async => const StandardMessageCodec().encodeMessage([null]),
        );
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final size in [const Size(360, 640), const Size(720, 1280)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final device = size.width < 600 ? 'phone' : 'tablet';
      for (final entry in <String, Widget>{
        '01-workouts': const WorkoutListScreen(),
        '02-editor': const WorkoutEditorScreen(workoutId: 'demo'),
        '03-briefing': WorkoutBriefingBoard(
          workout: demo,
          onStart: () {},
          onExit: () {},
        ),
        '04-sounds': const WorkoutEditorScreen(workoutId: 'demo'),
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                authStateProvider.overrideWith(
                  (ref) => Stream.value(
                    const AuthUser(
                      id: 'u',
                      email: 'coach@example.com',
                      displayName: 'Coach',
                      photoUrl: null,
                    ),
                  ),
                ),
                userProfileControllerProvider.overrideWith(_Profile.new),
                deviceModeControllerProvider.overrideWith(_Mode.new),
                displayDevicesProvider.overrideWith(
                  (ref) => Stream.value([_device]),
                ),
                brandTemplateProvider.overrideWith(
                  (ref) => Stream.value(BrandTemplate.initial()),
                ),
                workoutSchedulesProvider.overrideWith(
                  (ref) => Stream.value(const <WorkoutSchedule>[]),
                ),
                operationEventsProvider.overrideWith(
                  (ref) => Stream.value(const <OperationEvent>[]),
                ),
                workoutControllerProvider.overrideWith(_Workouts.new),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: XonTheme.light.copyWith(
                  platform: TargetPlatform.android,
                ),
                builder: XonTheme.responsiveBuilder,
                home: entry.value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (entry.key == '04-sounds') {
          await tester.tap(find.byTooltip('화면·사운드 설정'));
          await tester.pumpAndSettle();
          if (device == 'phone') {
            await tester.drag(
              find.byKey(const ValueKey('workout-settings-scroll')),
              const Offset(0, -350),
            );
            await tester.pumpAndSettle();
          }
        }
        expect(tester.takeException(), isNull, reason: '$device ${entry.key}');
        await save(
          tester,
          key,
          '$device-${entry.key}',
          device == 'phone' ? 3 : 1.5,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
    tester.view.physicalSize = const Size(1280, 720);
    final key = GlobalKey();
    final current = PlaybackSession(
      id: 'session',
      ownerId: 'u',
      zoneId: 'main',
      workout: demo,
      status: PlaybackStatus.paused,
      stepIndex: 0,
      remainingMs: 45000,
      anchorServerMs: DateTime.now().millisecondsSinceEpoch,
      revision: 1,
      updatedByDeviceId: 'phone',
    );

    final container = ProviderContainer(
      overrides: [
        activePlaybackSessionProvider.overrideWith(
          (ref) => Stream.value(current),
        ),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        playbackConnectionProvider.overrideWith((ref) => Stream.value(true)),
        androidTvProvider.overrideWith((ref) async => true),
      ],
    );
    container.listen(activePlaybackSessionProvider, (_, _) {});
    await tester.pump();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: XonTheme.light.copyWith(platform: TargetPlatform.android),
            builder: XonTheme.responsiveBuilder,
            home: const WorkoutPlayerScreen(
              workoutId: 'demo',
              startModule: 0,
              sessionId: 'session',
              displayMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await save(tester, key, 'tv-01-player', 1.5);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> save(
  WidgetTester tester,
  GlobalKey key,
  String name,
  double ratio,
) async {
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('docs/play-store/source').create(recursive: true);
    await File('docs/play-store/source/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

final _device = DisplayDevice(
  id: 'tv',
  name: '메인 디스플레이',
  zoneId: 'zone',
  zoneName: '트레이닝 존',
  online: true,
  lastSeenAtMs: 0,
  currentSessionId: null,
  acknowledgedRevision: 1,
  paired: true,
);

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}

class _Profile extends UserProfileController {
  @override
  Future<UserProfile> build() async => const UserProfile(
    id: 'u',
    email: 'coach@example.com',
    displayName: 'CloudBoard Coach',
    photoUrl: null,
  );
}

final demo =
    Workout.empty(
      'demo',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: '서킷 트레이닝',
      folder: '그룹 수업',
      brandL: 'CLOUD BOARD',
      brandR: 'MOVE AT YOUR PACE',
      modules: [
        WorkoutModule.empty('warmup').copyWith(
          name: '워밍업',
          text: '가볍게 제자리 걷기\n팔과 어깨 풀어 주기\n스쿼트 10회',
          workSeconds: 60,
          sets: 3,
          restSeconds: 20,
          beep: false,
          workGaugeColor: '#77729D',
          workTextColor: '#FFFFFF',
        ),
        WorkoutModule.empty('strength').copyWith(
          name: 'STRENGTH',
          text: '고블릿 스쿼트 12회\n푸시업 10회\n덤벨 로우 12회',
          workSeconds: 180,
          sets: 3,
          restSeconds: 30,
          beep: false,
        ),
        WorkoutModule.empty('conditioning').copyWith(
          name: 'CONDITIONING',
          text: '런지 12회\n마운틴 클라이머 20회\n플랭크 30초',
          workSeconds: 120,
          sets: 3,
          restSeconds: 30,
          beep: false,
        ),
        WorkoutModule.empty('cooldown').copyWith(
          name: '쿨다운',
          text: '호흡 정리\n하체 스트레칭',
          workSeconds: 120,
          beep: false,
        ),
      ],
    );

class _Workouts extends WorkoutController {
  @override
  Stream<List<Workout>> build() async* {
    yield [
      demo,
      demo.copyWith(id: 'strength', name: '전신 근력', folder: '그룹 수업'),
      demo.copyWith(id: 'interval', name: '인터벌 30', folder: '컨디셔닝'),
      demo.copyWith(id: 'mobility', name: '모빌리티', folder: '회복'),
      demo.copyWith(id: 'core', name: '코어 클래스', folder: '그룹 수업'),
    ];
  }
}
