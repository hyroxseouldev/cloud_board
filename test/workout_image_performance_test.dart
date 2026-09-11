import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'decoded Base64 bytes are reused and evicted within a memory budget',
    () {
      final cache = WorkoutImageBytesCache(maximumBytes: 25);
      final first = base64Encode([
        1,
        2,
        3,
      ]); // 3 bytes + 8 retained string bytes
      final second = base64Encode([4, 5, 6]);
      final third = base64Encode([7, 8, 9]);
      final bytes = cache.decode(first);
      final evicted = cache.decode(second);
      expect(identical(cache.decode(first), bytes), isTrue);
      cache.decode(third);
      expect(identical(cache.decode(first), bytes), isTrue);
      expect(identical(cache.decode(second), evicted), isFalse);
    },
  );

  test(
    'prefetch deduplicates, bounds concurrency, and stops after cancellation',
    () async {
      final pending = <Completer<void>>[];
      final requests = <String>[];
      var cancelled = false;
      final loading = warmWorkoutImages(
        ['a', 'a', '', 'b', 'c', 'd', 'e'],
        concurrency: 2,
        isCancelled: () => cancelled,
        load: (source) {
          requests.add(source);
          final done = Completer<void>();
          pending.add(done);
          return done.future;
        },
      );
      expect(requests, ['a', 'b']);
      pending[0].complete();
      await Future<void>.delayed(Duration.zero);
      expect(requests, ['a', 'b', 'c']);
      cancelled = true;
      pending[1].complete();
      pending[2].complete();
      expect(await loading, 3);
      expect(requests, ['a', 'b', 'c']);
    },
  );

  testWidgets('precache reports decoding errors to the preparation caller', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    await tester.runAsync(() async {
      await expectLater(
        precacheWorkoutImages(context, ['AQID']),
        throwsA(isA<Exception>()),
      );
    });
    expect(tester.takeException(), isNull);
  });

  test('decode resolution uses physical pixels and stays bounded', () {
    expect(workoutImageSize(const Size(320, 180), 2), (
      width: 640,
      height: 384,
    ));
    expect(workoutImageSize(const Size(9000, 6000), 3), (
      width: 3840,
      height: 3840,
    ));
  });
}
