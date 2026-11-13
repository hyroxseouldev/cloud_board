import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_image_budget.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image_budget_notice.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_list_card.dart';

const bucket = 'budget.appspot.com';
String url(String id, [String token = 'one']) =>
    'https://firebasestorage.googleapis.com/v0/b/$bucket/o/users%2Fcoach%2Fworkouts%2Flesson%2Fimages%2F$id?alt=media&token=$token';
Workout workout(List<String> sources, {String countdown = ''}) =>
    Workout.empty(
      'lesson',
      const WorkoutAuthor(id: 'coach', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      countdownImageSource: countdown,
      modules: [
        for (var i = 0; i < sources.length; i++)
          WorkoutModule.empty('$i').copyWith(imageSource: sources[i]),
      ],
    );
void main() {
  test('enrolled draft budget measures the exact raw upload bytes without invoking optimization', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final source = 'data:image/png;base64,${base64Encode(bytes)}';
    final usage = WorkoutImageUsageDataSource(
      ownerId: 'coach',
      bucket: bucket,
      readBytes: (_, _) async => null,
      useRawUploads: () async => true,
      optimize: (_) async =>
          throw StateError('Managed uploads must remain raw'),
    );
    final result = await usage.measure(workout([source, source]));
    expect(result.knownBytes, bytes.length);
    expect(result.failed, isFalse);
  });
  test(
    'decimal exact boundary, token dedup, countdown and per-slide values',
    () async {
      final reads = <String>[];
      final loader = WorkoutImageUsageDataSource(
        ownerId: 'coach',
        bucket: bucket,
        readBytes: (_, path) async {
          reads.add(path);
          return path.endsWith('/a') ? 60000000 : 40000000;
        },
      );
      final usage = await loader.measure(
        workout([url('a'), url('a', 'two'), url('b')], countdown: url('b')),
      );
      expect(usage.knownBytes, 100000000);
      expect(usage.exceedsLimit, false);
      expect(usage.moduleBytes['1'], 60000000);
      expect(usage.countdownBytes, 40000000);
      expect(reads.length, 2);
      await loader.measure(workout([url('a')]));
      expect(reads.length, 2);
      expect(
        WorkoutImageUsage(
          moduleBytes: {},
          countdownBytes: 0,
          knownBytes: 100000001,
          unknownCount: 0,
        ).exceedsLimit,
        true,
      );
      expect(imageMegabytes(100000000), '100.00 MB');
    },
  );
  test(
    'new local images count optimized bytes; same bytes deduplicated',
    () async {
      final bytes = Uint8List.fromList([71, 73, 70, 56, 57, 97, 1, 2, 3]);
      final source = 'data:image/gif;base64,${base64Encode(bytes)}';
      var optimizations = 0;
      final loader = WorkoutImageUsageDataSource(
        ownerId: 'coach',
        bucket: bucket,
        readBytes: (_, _) async => throw StateError('not remote'),
        optimize: (_) async {
          optimizations++;
          return WorkoutImageSource(
            bytes: Uint8List(5),
            contentType: 'image/gif',
          );
        },
      );
      final usage = await loader.measure(
        workout([source, source], countdown: source),
      );
      expect(usage.knownBytes, 5);
      expect(usage.moduleBytes.values, [5, 5]);
      expect(optimizations, 1);
    },
  );
  test(
    'metadata failures and foreign URLs are unknown, retry can recover',
    () async {
      var failing = true;
      final loader = WorkoutImageUsageDataSource(
        ownerId: 'coach',
        bucket: bucket,
        readBytes: (_, _) async {
          if (failing) throw StateError('offline');
          return 500;
        },
      );
      final usage = await loader.measure(
        workout([url('a'), 'https://elsewhere.test/image']),
      );
      expect(usage.unknownCount, 2);
      expect(usage.failed, true);
      expect(usage.moduleBytes['0'], isNull);
      expect(usage.totalLabel, startsWith('확인된 '));
      failing = false;
      loader.retry();
      expect((await loader.measure(workout([url('a')]))).knownBytes, 500);
    },
  );
  test('server rejection maps to actionable Korean guidance', () {
    final message = workoutErrorMessage(
      FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'internal',
        details: {
          'reason': 'workout-image-budget-exceeded',
          'totalBytes': 101000000,
        },
      ),
    );
    expect(message, contains('1.00 MB 초과'));
    expect(message, contains('다시 저장'));
    expect(message, isNot(contains('internal')));
  });
  testWidgets(
    'total, countdown, overage and each slide image size are visible',
    (tester) async {
      const usage = WorkoutImageUsage(
        moduleBytes: {'0': 101000000},
        countdownBytes: 1000000,
        knownBytes: 101000000,
        unknownCount: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WorkoutImageBudgetNotice(
                  usage: usage,
                  hasCountdown: true,
                  onRetry: () {},
                ),
                SizedBox(
                  height: 120,
                  child: WorkoutSlideListCard(
                    module: WorkoutModule.empty('0'),
                    index: 0,
                    imageSizeLabel: '101.00 MB',
                    menu: const SizedBox(),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('이미지 용량 · 101.00 MB / 100 MB'), findsOneWidget);
      expect(find.text('카운트다운 이미지 · 1.00 MB'), findsOneWidget);
      expect(find.text('이미지 · 101.00 MB'), findsOneWidget);
      expect(find.textContaining('1.00 MB 초과'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
