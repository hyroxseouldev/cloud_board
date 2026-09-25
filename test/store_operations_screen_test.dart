import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';

import 'support/workout_catalog_fixture.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/views/store_operations_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(834, 1194),
  ]) {
    testWidgets('매장 운영 하단 탭이 모두 보이고 초안을 유지한다: $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            brandTemplateProvider.overrideWith(
              (ref) => Stream.value(BrandTemplate.initial()),
            ),
            workoutSchedulesProvider.overrideWith(
              (ref) => Stream.value(const <WorkoutSchedule>[]),
            ),
            operationEventsProvider.overrideWith(
              (ref) => Stream.value(const <OperationEvent>[]),
            ),
            displayDevicesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            fixtureWorkoutDetails,
            workoutControllerProvider.overrideWith(_FakeWorkoutController.new),
          ],
          child: MaterialApp(
            theme: XonTheme.light,
            builder: XonTheme.responsiveBuilder,
            home: StoreOperationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byType(TabBar), findsNothing);
      final bar = find.byKey(const ValueKey('store-operations-tabs'));
      final barY = tester.getTopLeft(bar).dy;
      expect(barY, greaterThan(size.height / 2));
      for (final label in ['워크아웃', '대기 화면', '예약 재생', '원격 관리', '리포트']) {
        expect(
          find.descendant(of: bar, matching: find.text(label)).hitTestable(),
          findsOneWidget,
        );
      }
      var enteredDraft = false;
      for (final label in ['대기 화면', '예약 재생', '원격 관리', '리포트', '대기 화면']) {
        await tester.tap(find.descendant(of: bar, matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(bar).dy, barY);
        expect(tester.takeException(), isNull);
        if (label == '대기 화면') {
          final name = find.widgetWithText(TextField, '매장 이름');
          if (!enteredDraft) {
            enteredDraft = true;
            await tester.enterText(name, '저장 전 매장 이름');
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
          }
        }
      }
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '매장 이름'))
            .controller!
            .text,
        '저장 전 매장 이름',
      );
    });
  }
}

class _FakeWorkoutController extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() async* {
    yield const [];
  }
}
