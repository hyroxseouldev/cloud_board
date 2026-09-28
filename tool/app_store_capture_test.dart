import '../test/support/workout_catalog_fixture.dart';

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

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

// Run from repository root: fvm flutter test tool/app_store_capture_test.dart
// Captures current production widgets with iOS styling and local sample data only.
void main() {
  testWidgets('export current iOS App Store screenshots', (tester) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;

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
    for (final size in [const Size(428, 926), const Size(1024, 1366)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final device = size.width < 600 ? 'phone' : 'tablet';
      for (final entry in <String, Widget>{
        '01-workouts': const WorkoutListScreen(),
        '03-briefing': WorkoutBriefingBoard(
          workout: demo,
          onStart: () {},
          onExit: () {},
        ),
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                activePlaybackSessionProvider.overrideWith(
                  (ref) => Stream.value(null),
                ),
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
                fixtureWorkoutDetails,
                workoutControllerProvider.overrideWith(_Workouts.new),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: XonTheme.light.copyWith(platform: TargetPlatform.iOS),
                builder: XonTheme.responsiveBuilder,
                home: entry.value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$device ${entry.key}');
        await save(
          tester,
          key,
          '$device-${entry.key}',
          device == 'phone' ? 3 : 2,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
    debugDisableShadows = previousShadows;
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
    await Directory('docs/release/cloudboard-2026-09-28/apple/screenshots')
        .create(recursive: true);
    await File('docs/release/cloudboard-2026-09-28/apple/screenshots/$name.png')
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

class _Workouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() async* {
    yield [
      demo,
      demo.copyWith(id: 'strength', name: '전신 근력', folder: '그룹 수업'),
      demo.copyWith(id: 'interval', name: '인터벌 30', folder: '컨디셔닝'),
      demo.copyWith(id: 'mobility', name: '모빌리티', folder: '회복'),
      demo.copyWith(id: 'core', name: '코어 클래스', folder: '그룹 수업'),
    ];
  }
}
