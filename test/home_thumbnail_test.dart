import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/home_thumbnail_loader.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_workout_thumbnail.dart';

Uint8List tinyImage() => img.encodePng(
  img.Image(width: 32, height: 18)..clear(img.ColorRgb8(82, 107, 96)),
);
void main() {
  test('home accepts only canonical managed project/revision URI', () {
    const source =
        'https://asia-northeast3-cloud-board-development.cloudfunctions.net/cloudboardMedia?assetId=image-one&v=7';
    final uri = homeThumbnailUri(source, 'cloud-board-development')!;
    expect(uri.queryParameters['rendition'], 'home-v1');
    expect(uri.queryParameters['v'], '7');
    for (final invalid in [
      source.replaceFirst('https:', 'http:'),
      '$source&v=8',
      '$source&url=http://169.254.169.254',
      source.replaceFirst('image-one', '../other'),
      source.replaceFirst('cloudfunctions.net', 'evil.example'),
    ]) {
      expect(homeThumbnailUri(invalid, 'cloud-board-development'), isNull);
    }
    expect(homeThumbnailUri(source, 'cloud-board-stationd'), isNull);
  });
  test('bounded embedded still bytes work; malformed/large/unknown remote stay local', () async {
    final loader = HomeThumbnailLoader('owner');
    addTearDown(loader.dispose);
    final bytes = tinyImage();
    expect(
      await loader.load('data:image/png;base64,${base64Encode(bytes)}'),
      bytes,
    );
    expect(await loader.load('not-an-image'), isNull);
    expect(await loader.load('a' * 100000), isNull);
    expect(await loader.load('https://example.invalid/100MB.png'), isNull);
    expect(await loader.load('data:image/gif;base64,AAAA'), isNull);
  });
  test(
    'one body per source revision, bounded cache, no cross-account bytes',
    () async {
      final calls = <String>[];
      final a = HomeThumbnailCache((source) async {
        calls.add(source);
        return tinyImage();
      });
      final first = await a.load('asset?v=7');
      expect(identical(await a.load('asset?v=7'), first), isTrue);
      await a.load('asset?v=8');
      expect(calls, ['asset?v=7', 'asset?v=8']);
      a.dispose();
      expect(await a.load('asset?v=7'), isNull);
      final b = HomeThumbnailCache((source) async {
        calls.add('account-b/$source');
        return tinyImage();
      });
      await b.load('asset?v=7');
      expect(calls.last, 'account-b/asset?v=7');
      b.dispose();
    },
  );
  test('failures settle to placeholder without retry loops and dispose cancels queued work', () async {
    var calls = 0;
    final gate = Completer<Uint8List?>();
    final cache = HomeThumbnailCache((_) {
      calls++;
      return gate.future;
    });
    final one = cache.load('one');
    final two = cache.load('two');
    await Future<void>.delayed(Duration.zero);
    cache.dispose();
    gate.complete(tinyImage());
    expect(await one, isNull);
    expect(await two, isNull);
    expect(calls, 1);
    var failures = 0;
    final failing = HomeThumbnailCache((_) async {
      failures++;
      throw StateError('offline');
    });
    expect(await failing.load('one'), isNull);
    expect(await failing.load('one'), isNull);
    expect(failures, 1);
    failing.dispose();
  });
  test('cells leaving viewport cancel queued requests; managed clones share source', () async {
    final gate = Completer<Uint8List?>();
    final calls = <String>[];
    final cache = HomeThumbnailCache((source) {
      calls.add(source);
      return gate.future;
    });
    final revision = DateTime(2026);
    final visible = cache.watch('visible', revision);
    final offscreen = cache.watch('offscreen', revision);
    offscreen.release();
    await Future<void>.delayed(Duration.zero);
    gate.complete(tinyImage());
    await visible.future;
    expect(await offscreen.future, isNull);
    expect(calls, ['visible']);
    visible.release();
    cache.dispose();
  });

  testWidgets(
    'fixed image-only slot drops stale source and broken images gracefully',
    (tester) async {
      final cache = HomeThumbnailCache(
        (source) async =>
            source == 'good' ? tinyImage() : Uint8List.fromList([1, 2, 3]),
      );
      addTearDown(cache.dispose);
      Future<void> mount(String source) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeThumbnailCacheProvider('owner').overrideWithValue(cache),
          ],
          child: MaterialApp(
            home: Center(
              child: HomeWorkoutThumbnail(
                ownerId: 'owner',
                workout: WorkoutSummary(
                  id: 'w',
                  name: 'Class',
                  folder: '',
                  imageSource: source,
                  moduleCount: 1,
                  durationSeconds: 30,
                  updatedAt: DateTime(2026),
                ),
              ),
            ),
          ),
        ),
      );
      await mount('good');
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(HomeWorkoutThumbnail)),
        const Size(56, 56),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('30'), findsNothing);
      await mount('bad');
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
