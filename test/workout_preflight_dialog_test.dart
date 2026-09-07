import 'dart:convert';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
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

  testWidgets('온라인 디스플레이 여러 대를 기본으로 모두 선택한다', (tester) async {
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
          modules: [WorkoutModule.empty('module').copyWith(name: '스쿼트')],
        );
    const devices = [
      DisplayDevice(
        id: 'display-a',
        name: '메인 TV',
        zoneId: 'main',
        zoneName: '메인 구역',
        online: true,
        lastSeenAtMs: 1,
        currentSessionId: null,
        acknowledgedRevision: 0,
        paired: true,
      ),
      DisplayDevice(
        id: 'display-b',
        name: '보조 TV',
        zoneId: 'main',
        zoneName: '메인 구역',
        online: true,
        lastSeenAtMs: 1,
        currentSessionId: null,
        acknowledgedRevision: 0,
        paired: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          displayDevicesProvider.overrideWith((ref) => Stream.value(devices)),
        ],
        child: MaterialApp(home: WorkoutPreflightDialog(workout: workout)),
      ),
    );
    await tester.pump();
    await tester.pump();

    final checkboxes = tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(checkboxes.length, 2);
    expect(checkboxes.every((tile) => tile.value == true), isTrue);
    expect(find.text('2대를 선택했습니다.'), findsOneWidget);
  });
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
