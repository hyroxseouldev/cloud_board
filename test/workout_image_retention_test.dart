import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_retention.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _image = 'https://example.test/slide.png';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prepared compressed image transfers to a different playback ID and survives cache eviction', () async {
    var requests = 0;
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5X8AAAAASUVORK5CYII=',
    );
    final retained = WorkoutImageRetention(
      clientFactory: () => MockClient((_) async {
        requests++;
        return http.Response.bytes(bytes, 200);
      }),
    );
    addTearDown(retained.dispose);
    retained.prepare(
      'prepare-a',
      const Duration(seconds: 90),
      sources: [_image],
    );
    await retained.load(_image);
    retained.activate('actual-class', sources: [_image]);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final provider = workoutImageProvider(_image, (width: null, height: null));
    expect(provider, isA<MemoryImage>());
    expect((provider as MemoryImage).bytes, orderedEquals(bytes));
    await retained.load(_image);
    expect(requests, 1);
    retained.clear();
    expect(retained.retainedBytes, 0);
    expect(retainedWorkoutImage(_image), isNull);
    expect(
      workoutImageProvider(_image, (width: null, height: null)),
      isNot(isA<MemoryImage>()),
    );
  });

  test(
    'class and per-image caps reject excess without evicting prepared images',
    () async {
      final retained = WorkoutImageRetention(
        maximumBytes: 8,
        maximumImageBytes: 6,
        clientFactory: () => MockClient(
          (request) async => http.Response.bytes(
            List.filled(request.url.path == '/large' ? 7 : 5, 1),
            200,
          ),
        ),
      );
      addTearDown(retained.dispose);
      retained.activate('class', sources: [_image]);
      await retained.load(_image);
      await expectLater(
        retained.load('https://example.test/large'),
        throwsStateError,
      );
      await expectLater(
        retained.load('https://example.test/second'),
        throwsStateError,
      );
      expect(retained.retainedBytes, 5);
      expect(retained.bytesFor(_image), hasLength(5));
      retained.activate('other', sources: ['https://example.test/other']);
      expect(retained.retainedBytes, 0);
      expect(retained.bytesFor(_image), isNull);
    },
  );

  test(
    'CORS fallback pins are bounded and released on replacement/dispose',
    () {
      var released = 0;
      final retained = WorkoutImageRetention(maximumBytes: 8);
      retained.activate('class');
      expect(retained.retainFallback(_image, 8, () => released++), isTrue);
      expect(retained.retainFallback('other', 1, () => released++), isFalse);
      retained.activate('next', sources: ['other']);
      expect(released, 1);
      expect(retained.retainedBytes, 0);
      retained.retainFallback('other', 4, () => released++);
      retained.dispose();
      expect(released, 2);
    },
  );

  test(
    'late old download cannot restore bytes into replacement class',
    () async {
      final response = Completer<http.Response>();
      final retained = WorkoutImageRetention(
        clientFactory: () => MockClient((_) => response.future),
      );
      addTearDown(retained.dispose);
      retained.activate('old', sources: [_image]);
      final pending = retained.load(_image);
      await Future<void>.delayed(Duration.zero);
      retained.activate('new', sources: ['other']);
      response.complete(http.Response.bytes([1, 2, 3], 200));
      await pending;
      expect(retained.bytesFor(_image), isNull);
      expect(retained.retainedBytes, 0);
    },
  );

  test(
    'one failed image does not prevent later active slides loading',
    () async {
      final loaded = <String>[];
      final count = await warmWorkoutImages(
        ['bad', 'second', 'third'],
        concurrency: 1,
        continueOnError: true,
        load: (source) async {
          if (source == 'bad') throw StateError('offline');
          loaded.add(source);
        },
      );
      expect(count, 2);
      expect(loaded, ['second', 'third']);
    },
  );

  testWidgets('unclaimed preparation expires, active class cancels expiry', (
    tester,
  ) async {
    final retained = WorkoutImageRetention();
    addTearDown(retained.dispose);
    retained.prepare(
      'candidate',
      const Duration(seconds: 1),
      sources: [_image],
    );
    await tester.pump(const Duration(seconds: 1));
    expect(retained.sessionId, isNull);
    retained.prepare(
      'candidate2',
      const Duration(seconds: 1),
      sources: [_image],
    );
    retained.activate('live', sources: [_image]);
    await tester.pump(const Duration(hours: 1));
    expect(retained.sessionId, 'live');
  });
}
