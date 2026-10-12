import 'dart:convert';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';

import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('이미지 준비 오류는 원문을 숨기고 진단 정보와 복구 안내를 유지한다', (tester) async {
    final sink = _PreflightDiagnostics();
    final workout =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'user',
            displayName: 'Tester',
            photoUrl: null,
          ),
        ).copyWith(
          modules: [
            WorkoutModule.empty('module').copyWith(
              imageSource: 'data:image/png;base64,TECHNICAL_PRIVATE%%',
            ),
          ],
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          displayDevicesProvider.overrideWith((ref) => Stream.value(const [])),
          errorReporterProvider.overrideWithValue(ErrorReporter(sink)),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: WorkoutPreflightDialog(workout: workout),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이미지 준비 실패'), findsOneWidget);
    expect(find.textContaining('인터넷 연결과 슬라이드 이미지'), findsOneWidget);
    expect(find.textContaining('TECHNICAL_PRIVATE'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '수업 시작'))
          .onPressed,
      isNull,
    );
    expect(sink.events.single.error, isA<FormatException>());
    expect(sink.events.single.context['action'], 'workout.preflight.images');
    expect(tester.takeException(), isNull);
  });
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
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: WorkoutPreflightDialog(workout: workout),
        ),
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
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: WorkoutPreflightDialog(workout: workout),
        ),
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

    await tester.ensureVisible(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pump();
    expect(find.text('브리핑 미리보기'), findsNothing);
    expect(find.text('소리 테스트'), findsNothing);
    expect(find.text('1대를 선택했습니다.'), findsOneWidget);
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .map((tile) => tile.value),
      [true, false],
    );
  });
}

class _PreflightDiagnostics implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  @override
  Future<void> send(DiagnosticEvent event) async => events.add(event);
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
