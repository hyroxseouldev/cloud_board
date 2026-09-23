import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_board/src/app/core/utils/bounded_map.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_optimizer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';

void main() {
  test(
    'large JPEG shrinks within display limit, small JPEG stays byte-identical',
    () async {
      final large = img.Image(width: 3200, height: 1800);
      for (var y = 0; y < large.height; y++) {
        for (var x = 0; x < large.width; x++) {
          large.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
        }
      }
      final input = WorkoutImageSource(
        bytes: Uint8List.fromList(img.encodeJpg(large, quality: 100)),
        contentType: 'image/jpeg',
      );
      final output = await optimizeWorkoutImage(input);
      final decoded = img.decodeJpg(output.bytes)!;
      expect(decoded.width, 2560);
      expect(decoded.height, 1440);
      expect(output.bytes.length, lessThan(input.bytes.length));
      final small = WorkoutImageSource(
        bytes: Uint8List.fromList(
          img.encodeJpg(img.Image(width: 20, height: 10)),
        ),
        contentType: 'image/jpeg',
      );
      expect(identical(optimizeWorkoutImageBytes(small), small), isTrue);
    },
  );

  test(
    'PNG preserves alpha and animated formats keep exact original bytes',
    () {
      final png = img.Image(width: 4000, height: 2, numChannels: 4);
      for (var x = 0; x < png.width; x++) {
        png.setPixelRgba(x, 0, x % 256, 90, 180, 80);
      }
      final original = WorkoutImageSource(
        bytes: Uint8List.fromList(img.encodePng(png, level: 0)),
        contentType: 'image/png',
      );
      final output = optimizeWorkoutImageBytes(original);
      expect(output.contentType, 'image/png');
      expect(img.decodePng(output.bytes)!.getPixel(0, 0).a, lessThan(255));
      for (final type in ['image/gif', 'image/webp']) {
        final input = WorkoutImageSource(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: type,
        );
        expect(identical(optimizeWorkoutImageBytes(input), input), isTrue);
      }
    },
  );

  test(
    'bounded uploads preserve order and drain active requests before failure',
    () async {
      var active = 0, peak = 0, started = 0;
      final result = await boundedMap(List.generate(8, (i) => i), (i) async {
        active++;
        started++;
        if (active > peak) peak = active;
        await Future<void>.delayed(Duration(milliseconds: 10 - i));
        active--;
        return i * 2;
      });
      expect(result, List.generate(8, (i) => i * 2));
      expect(peak, 3);
      started = 0;
      await expectLater(
        boundedMap(List.generate(10, (i) => i), (i) async {
          started++;
          active++;
          try {
            if (i == 0) throw StateError('failed');
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return i;
          } finally {
            active--;
          }
        }),
        throwsStateError,
      );
      expect(started, lessThanOrEqualTo(3));
      expect(active, 0);
    },
  );

  test('duplicate slide images upload once with completion progress', () async {
    final storage = _Storage();
    final workout =
        Workout.empty(
          'w',
          const WorkoutAuthor(id: 'u', displayName: 'coach', photoUrl: null),
        ).copyWith(
          modules: [
            for (final source in ['local-a', 'local-b', 'local-a'])
              WorkoutModule.empty(source).copyWith(imageSource: source),
          ],
          countdownImageSource: 'local-b',
        );
    final progress = <(int, int)>[];
    final result = await storage.syncImages(
      'u',
      workout,
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(storage.calls, ['local-a', 'local-b']);
    expect(result.modules.map((m) => m.imageSource), [
      'https://test/local-a',
      'https://test/local-b',
      'https://test/local-a',
    ]);
    expect(result.countdownImageSource, 'https://test/local-b');
    expect(progress, [(0, 2), (1, 2), (2, 2)]);
  });
}

class _FirebaseStorage extends Fake implements FirebaseStorage {}

class _Storage extends WorkoutStorageDataSource {
  _Storage() : super(_FirebaseStorage());
  final calls = <String>[];
  @override
  Future<String> uploadImage(String uid, String id, String source) async {
    calls.add(source);
    return 'https://test/$source';
  }
}
