import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_rehearsal_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _module = WorkoutModule.empty('rehearsal').copyWith(
  name: '전신 서킷 트레이닝',
  text: '나만의 페이스로 움직여 보세요',
  workSeconds: 5,
  restSeconds: 2,
  sets: 2,
  beep: false,
);

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(844, 390),
    const Size(1194, 834),
  ]) {
    testWidgets(
      'rehearsal controls preserve playback and slide appearance at $size',
      (tester) async {
        final container = await _mount(tester, size, _module);
        final provider = slideRehearsalControllerProvider(_module);
        Future<void> tap(String text) async {
          final target = find.text(text);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pump();
        }

        WorkoutSlideCanvas canvas() =>
            tester.widget<WorkoutSlideCanvas>(find.byType(WorkoutSlideCanvas));
        expect(canvas().module, _module);
        expect(canvas().brandL, 'CloudBoard');
        expect(canvas().brandR, 'Stationd');
        expect(canvas().secondsLeft, 5);
        await tap('마지막 3초');
        expect(canvas().secondsLeft, 3);
        expect(container.read(provider).positionMs, 2000);
        await tap('휴식으로');
        expect(canvas().isRest, isTrue);
        expect(canvas().secondsLeft, 2);
        expect(container.read(provider).positionMs, 5000);
        await tap('재생');
        expect(container.read(provider).playing, isTrue);
        expect(find.text('재생 중'), findsOneWidget);
        await tester.tap(find.text('일시정지'));
        await tester.pump();
        expect(container.read(provider).playing, isFalse);
        await tap('처음으로');
        expect(container.read(provider).positionMs, 0);
        expect(canvas().isRest, isFalse);
        final seek = find.byKey(const ValueKey('rehearsal-seek'));
        await tester.ensureVisible(seek);
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getTopRight(seek) - const Offset(1, -24));
        await tester.pump();
        expect(container.read(provider).positionMs, 12000);
        expect(find.text('재생 완료'), findsOneWidget);
        await tap('재생');
        expect(container.read(provider).positionMs, 0);
        expect(container.read(provider).playing, isTrue);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(container.read(provider).playing, isFalse);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(container.read(provider).playing, isFalse);
        await tester.ensureVisible(find.text('전환음 듣기'));
        await tester.pumpAndSettle();
        expect(find.text('전환음 듣기').hitTestable(), findsOneWidget);
        expect(container.exists(playbackActionControllerProvider), isFalse);
        expect(container.exists(workoutActionControllerProvider), isFalse);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('편집 화면'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('no-rest feedback and large text remain reachable', (
    tester,
  ) async {
    final module = _module.copyWith(restSeconds: 0, sets: 1);
    final container = await _mount(
      tester,
      const Size(390, 844),
      module,
      textScale: 2,
    );
    final button = find.text('휴식으로');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('이 슬라이드에는 휴식 구간이 없습니다.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(
      container.read(slideRehearsalControllerProvider(module)).positionMs,
      0,
    );
    await tester.ensureVisible(find.text('전환음 듣기'));
    await tester.pumpAndSettle();
    expect(find.text('전환음 듣기').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  Size size,
  WorkoutModule module, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SlideRehearsalScreen(
                    module: module,
                    brandL: 'CloudBoard',
                    brandR: 'Stationd',
                  ),
                ),
              ),
              child: const Text('편집 화면'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('편집 화면'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SlideRehearsalScreen)),
  );
}
