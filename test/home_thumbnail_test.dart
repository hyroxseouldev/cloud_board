import 'support/home_thumbnail_pump.dart';

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
      final a = HomeThumbnailCache((source, {workoutId, updatedAt}) async {
        calls.add(source);
        return tinyImage();
      });
      final first = await a.load('asset?v=7');
      expect(identical(await a.load('asset?v=7'), first), isTrue);
      await a.load('asset?v=8');
      expect(calls, ['asset?v=7', 'asset?v=8']);
      a.dispose();
      expect(await a.load('asset?v=7'), isNull);
      final b = HomeThumbnailCache((source, {workoutId, updatedAt}) async {
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
    final cache = HomeThumbnailCache((_, {workoutId, updatedAt}) {
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
    final failing = HomeThumbnailCache((_, {workoutId, updatedAt}) async {
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
    final cache = HomeThumbnailCache((source, {workoutId, updatedAt}) {
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

  test('legacy cache identity includes workout and revision, managed copies share generation', () async {
    final calls = <(String, String?, DateTime?)>[];
    final cache = HomeThumbnailCache((source, {workoutId, updatedAt}) async {
      calls.add((source, workoutId, updatedAt));
      return tinyImage();
    });
    final first = DateTime(2026);
    final changed = first.add(const Duration(seconds: 1));
    final a = cache.watch('legacy', first, workoutId: 'one');
    final duplicate = cache.watch('legacy', first, workoutId: 'one');
    expect(identical(a.future, duplicate.future), isTrue);
    await a.future;
    await cache.watch('legacy', first, workoutId: 'copy').future;
    await cache.watch('legacy', changed, workoutId: 'one').future;
    expect(calls.length, 3);
    const managed = 'https://example.invalid/cloudboardMedia?assetId=a&v=1';
    await cache.watch(managed, first, workoutId: 'one').future;
    await cache.watch(managed, changed, workoutId: 'copy').future;
    expect(calls.length, 4);
    cache.dispose();
  });

  test(
    'compressed cache stays at 32 entries and pending work stays bounded',
    () async {
      var calls = 0;
      final cache = HomeThumbnailCache((_, {workoutId, updatedAt}) async {
        calls++;
        return tinyImage();
      });
      for (var i = 0; i < 33; i++) {
        await cache.load('source-$i');
      }
      await cache.load('source-1');
      expect(calls, 33);
      await cache.load('source-0');
      expect(calls, 34, reason: 'The oldest of 33 entries was evicted');
      cache.dispose();
      final gate = Completer<Uint8List?>();
      var activeCalls = 0;
      final bounded = HomeThumbnailCache((_, {workoutId, updatedAt}) {
        activeCalls++;
        return gate.future;
      });
      final pending = [for (var i = 0; i < 8; i++) bounded.load('source-$i')];
      expect(await bounded.load('overflow'), isNull);
      expect(activeCalls, 1);
      gate.complete(tinyImage());
      await Future.wait(pending);
      expect(activeCalls, 8);
      bounded.dispose();
    },
  );

  testWidgets(
    'covered route releases queued thumbnail work and resume can request it',
    (tester) async {
      final blocker = Completer<Uint8List?>();
      final calls = <String>[];
      final cache = HomeThumbnailCache((source, {workoutId, updatedAt}) {
        calls.add(source);
        return source == 'blocker' ? blocker.future : Future.value(tinyImage());
      });
      addTearDown(cache.dispose);
      final first = cache.load('blocker');
      Future<void> mount(bool active) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeThumbnailCacheProvider('owner').overrideWithValue(cache),
          ],
          child: MaterialApp(
            home: TickerMode(
              enabled: active,
              child: Center(
                child: HomeWorkoutThumbnail(
                  ownerId: 'owner',
                  workout: WorkoutSummary(
                    id: 'w',
                    name: 'class',
                    folder: '',
                    imageSource: 'queued',
                    moduleCount: 1,
                    durationSeconds: 30,
                    updatedAt: DateTime(2026),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await mount(true);
      await tester.pump();
      await mount(false);
      await tester.pump();
      blocker.complete(tinyImage());
      await first;
      await pumpHomeThumbnails(tester);
      expect(calls, ['blocker']);
      await mount(true);
      await pumpHomeThumbnails(tester);
      expect(calls, ['blocker', 'queued']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fixed image-only slot drops stale source and broken images gracefully',
    (tester) async {
      final cache = HomeThumbnailCache(
        (source, {workoutId, updatedAt}) async =>
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
      await pumpHomeThumbnails(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await pumpHomeThumbnails(tester);
      expect(
        tester.getSize(find.byType(HomeWorkoutThumbnail)),
        const Size(108, 60.75),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('30'), findsNothing);
      await mount('bad');
      await pumpHomeThumbnails(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await pumpHomeThumbnails(tester);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
