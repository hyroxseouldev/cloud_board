import 'dart:convert';

import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('이미지 프리로드는 첫 프레임 이후 안전하게 시작한다', (tester) async {
    final workout =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'user',
            displayName: 'Tester',
            photoUrl: null,
          ),
        ).copyWith(
          name: '테스트 운동',
          modules: [
            WorkoutModule.empty('module').copyWith(
              name: '스쿼트',
              imageSource:
                  'data:image/png;base64,${base64Encode(_onePixelPng)}',
            ),
          ],
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          displayDevicesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(home: WorkoutPreflightDialog(workout: workout)),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
