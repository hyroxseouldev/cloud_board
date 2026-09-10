import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/standby_settings_screen.dart';

import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/store_operations_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

void main() {
  testWidgets(
    'empty home exposes standby settings without opening profile menu',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final guard = ExitGuard();
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const WorkoutListScreen()),
          GoRoute(
            path: '/operations/standby',
            builder: (_, _) => StandbySettingsScreen(guard: guard),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            deviceModeControllerProvider.overrideWith(_FakeMode.new),
            workoutControllerProvider.overrideWith(_FakeWorkoutController.new),
            displayDevicesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            brandTemplateProvider.overrideWith(
              (ref) => Stream.value(BrandTemplate.initial()),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '스탠바이 설정'));
      await tester.pumpAndSettle();
      expect(find.text('스탠바이 설정'), findsOneWidget);
      expect(find.text('전환 효과'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('작은 화면에서 매장 운영의 모든 탭이 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          brandTemplateProvider.overrideWith(
            (ref) => Stream.value(BrandTemplate.initial()),
          ),
          workoutSchedulesProvider.overrideWith(
            (ref) => Stream.value(const <WorkoutSchedule>[]),
          ),
          operationEventsProvider.overrideWith(
            (ref) => Stream.value(const <OperationEvent>[]),
          ),
          displayDevicesProvider.overrideWith((ref) => Stream.value(const [])),
          workoutControllerProvider.overrideWith(_FakeWorkoutController.new),
        ],
        child: const MaterialApp(home: StoreOperationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final label in ['예약 재생', '원격 관리', '운영 리포트']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

class _FakeWorkoutController extends WorkoutController {
  @override
  Future<List<Workout>> build() async => const [];
}

class _FakeMode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}
