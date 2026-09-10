import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _workout = Workout.empty(
  'workout',
  const WorkoutAuthor(id: 'coach', displayName: 'Coach', photoUrl: null),
).copyWith(name: '스테이션 D', brandL: 'CloudBoard', brandR: 'Station D');

void main() {
  testWidgets('화면·사운드 설정은 요약만 보이고 기본적으로 접힌다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(
                id: 'coach',
                email: 'coach@example.com',
                displayName: 'Coach',
                photoUrl: null,
              ),
            ),
          ),
          workoutControllerProvider.overrideWith(_TestWorkouts.new),
        ],
        child: const MaterialApp(
          home: WorkoutEditorScreen(workoutId: 'workout'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('화면·사운드 설정'), findsOneWidget);
    expect(
      find.text('왼쪽 “CloudBoard” · 오른쪽 “Station D” · 클래식 비프 100%'),
      findsOneWidget,
    );
    expect(find.text('화면 왼쪽 아래 문구'), findsNothing);
    expect(find.text('수업 사운드'), findsNothing);

    await tester.tap(find.text('화면·사운드 설정'));
    await tester.pumpAndSettle();

    expect(find.text('화면 왼쪽 아래 문구'), findsOneWidget);
    expect(find.text('화면 오른쪽 아래 문구'), findsOneWidget);
    expect(find.text('수업 사운드'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestWorkouts extends WorkoutController {
  @override
  Future<List<Workout>> build() async => [_workout];
}
